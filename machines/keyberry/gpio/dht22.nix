{ config, pkgs, lib, inputs, ... }:

let
  # Custom Adafruit_DHT package for pi400 - fully declarative
  adafruit-dht-pi400 = pkgs.python3Packages.buildPythonPackage {
    pname = "Adafruit_Python_DHT";
    version = "1.4.0-pi400";
    src = pkgs.fetchFromGitHub {
      owner = "ritiek";
      repo = "Adafruit_Python_DHT";
      rev = "bdf6d7dc56dbcb2bb82477e2ab9d3cd83047c986";
      hash = "sha256-VAGaBmDzh/1O2bjAOP46TZkrBtSVn/iHnAMMx3G8YWw=";
    };
    format = "setuptools";
  };

  dht22Script = pkgs.writeText "dht22_reader.py" ''
    #!/usr/bin/env python3
    import sys
    import json
    import Adafruit_DHT

    # Parse command line parameters - use numeric constants for custom package
    sensor_args = { '11': Adafruit_DHT.DHT11,
                    '22': Adafruit_DHT.DHT22,
                    '2302': Adafruit_DHT.AM2302 }

    # Default to DHT22 on GPIO pin 4 (common configuration)
    sensor_type = sys.argv[1] if len(sys.argv) > 1 else '22'
    pin = sys.argv[2] if len(sys.argv) > 2 else '4'

    if sensor_type not in sensor_args:
        print(f"Invalid sensor type: {sensor_type}", file=sys.stderr)
        print("Valid types: 11 (DHT11), 22 (DHT22), 2302 (AM2302)", file=sys.stderr)
        sys.exit(1)

    sensor = sensor_args[sensor_type]

    # Try to grab a sensor reading. Use the read_retry method which will retry up
    # to 15 times to get a sensor reading (waiting 2 seconds between each retry).
    humidity, temperature = Adafruit_DHT.read_retry(sensor, pin)

    # Note that sometimes you won't get a reading and
    # results will be null (because Linux can't
    # guarantee the timing of calls to read the sensor).
    if humidity is not None and temperature is not None:
        data = {
            'temperature': round(temperature, 1),
            'humidity': round(humidity, 1),
            'sensor_type': sensor_type,
            'pin': int(pin)
        }
        print(json.dumps(data))
    else:
        print("Failed to get reading. Try again!", file=sys.stderr)
        sys.exit(1)
  '';

  dht22-mqtt-loop = pkgs.writeShellScriptBin "dht22-mqtt-loop" ''
    echo "DHT22 MQTT service starting..."

    # Function to handle failures
    handle_failure() {
      # Notify Uptime Kuma of failure
      source ${config.sops.secrets."uptime-kuma.env".path}
      ${pkgs.curl}/bin/curl -s "$UPTIME_KUMA_INSTANCE_URL/api/push/31dW2vUcSq?status=down&msg=Failed&ping=" || true
    }

    while true; do
      echo ""
      echo "DHT22 reading cycle starting..."

      # Try to read sensor data with detailed error output
      if sensor_data=$(${pkgs.python3.withPackages (ps: with ps; [ adafruit-dht-pi400 ])}/bin/python3 ${dht22Script} 22 4 2>&1); then
        if [ -n "$sensor_data" ]; then
          # Parse JSON data
          temperature=$(echo "$sensor_data" | ${pkgs.jq}/bin/jq -r '.temperature')
          humidity=$(echo "$sensor_data" | ${pkgs.jq}/bin/jq -r '.humidity')

          echo "Sensor readings: Temp=$temperature°C, Humidity=$humidity%"

          # Read MQTT configuration
          mqtt_hosts_content=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."mqtt.hosts".path})
          mqtt_topic_base=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."mqtt.topic.base".path})

          # Publish to all MQTT brokers
          publish_success=false
          while IFS= read -r mqtt_host_port; do
            [ -z "$mqtt_host_port" ] && continue
            mqtt_host=$(echo "$mqtt_host_port" | ${pkgs.coreutils}/bin/cut -d: -f1)
            mqtt_port=$(echo "$mqtt_host_port" | ${pkgs.coreutils}/bin/cut -d: -f2)

            echo "Publishing to MQTT broker: $mqtt_host:$mqtt_port"

            # Publish temperature
            if echo "$temperature" | ${pkgs.mosquitto}/bin/mosquitto_pub -h "$mqtt_host" -p "$mqtt_port" -t "$mqtt_topic_base-dht22-temp" -l; then
              echo "  ✓ Temperature published to $mqtt_topic_base-dht22-temp"
              publish_success=true
            fi

            # Publish humidity
            if echo "$humidity" | ${pkgs.mosquitto}/bin/mosquitto_pub -h "$mqtt_host" -p "$mqtt_port" -t "$mqtt_topic_base-dht22-humidity" -l; then
              echo "  ✓ Humidity published to $mqtt_topic_base-dht22-humidity"
            fi

          done <<< "$mqtt_hosts_content"

          echo "  ✓ All sensors published"
          publish_success=true

          if [ "$publish_success" = true ]; then
            # Notify Uptime Kuma of success
            source ${config.sops.secrets."uptime-kuma.env".path}
            ${pkgs.curl}/bin/curl -s "$UPTIME_KUMA_INSTANCE_URL/api/push/31dW2vUcSq?status=up&msg=OK&ping=" || true
          else
            echo "MQTT publishing failed"
          fi
        else
          echo "Sensor reading is empty"
          handle_failure
        fi
      else
        echo "Failed to read DHT22 sensor: $sensor_data"
        handle_failure
      fi

      echo "DHT22 cycle completed, sleeping 60 seconds..."
      ${pkgs.coreutils}/bin/sleep 60
    done
  '';
in
{
  sops = {
    secrets = {
      "mqtt.hosts" = {
        sopsFile = ./secrets.yaml;
      };
      "mqtt.topic.base" = {
        sopsFile = ./secrets.yaml;
      };
      "uptime-kuma.env" = {
        sopsFile = ./../secrets.yaml;
      };
    };
  };

  systemd.services.dht22-mqtt = {
    description = "DHT22 temperature/humidity sensor to MQTT";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = "10s";
      ExecStart = "${dht22-mqtt-loop}/bin/dht22-mqtt-loop";
    };
  };
}
