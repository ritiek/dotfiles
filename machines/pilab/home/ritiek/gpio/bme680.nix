{ config, pkgs, lib, inputs, ... }:

let
  bme680Script = pkgs.writeText "bme680_reader.py" ''
    #!/usr/bin/env python3
    import bme680
    import time
    import sys

    try:
        sensor = bme680.BME680(bme680.I2C_ADDR_PRIMARY)
    except (RuntimeError, IOError):
        sensor = bme680.BME680(bme680.I2C_ADDR_SECONDARY)

    sensor.set_humidity_oversample(bme680.OS_2X)
    sensor.set_pressure_oversample(bme680.OS_4X)
    sensor.set_temperature_oversample(bme680.OS_8X)
    sensor.set_filter(bme680.FILTER_SIZE_3)

    if sensor.get_sensor_data():
        output = '{0:.2f}'.format(sensor.data.temperature)
        print(output, end="")
    else:
        print("Failed to read sensor data", file=sys.stderr)
        sys.exit(1)
  '';

  bme680-mqtt-loop = pkgs.writeShellScriptBin "bme680-mqtt-loop" ''
    echo "BME680 continuous service starting..."
    
    while true; do
      echo "BME680 reading cycle starting..."
      
      # Try to read temperature with detailed error output
      if temperature=$(${pkgs.python3.withPackages (ps: with ps; [ bme680 ])}/bin/python ${bme680Script} 2>&1); then
        if [ -n "$temperature" ]; then
          echo "Temperature reading: $temperature°C"
          
          # Read MQTT configuration
          mqtt_host_port=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."mqtt.host".path})
          mqtt_host=$(echo "$mqtt_host_port" | ${pkgs.coreutils}/bin/cut -d: -f1)
          mqtt_port=$(echo "$mqtt_host_port" | ${pkgs.coreutils}/bin/cut -d: -f2)
          mqtt_topic_temperature=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."mqtt.topic.temperature".path})
          
          # Publish to MQTT
          echo "Publishing to MQTT: $mqtt_host:$mqtt_port topic $mqtt_topic_temperature"
          if echo "$temperature" | ${pkgs.mosquitto}/bin/mosquitto_pub -h "$mqtt_host" -p "$mqtt_port" -t "$mqtt_topic_temperature" -l; then
            echo "MQTT publish successful"
            
            # Notify Uptime Kuma of success
            source ${config.sops.secrets."uptime-kuma.env".path}
            ${pkgs.curl}/bin/curl -s "$UPTIME_KUMA_INSTANCE_URL/api/push/B1hhLs9hts?status=up&msg=OK&ping=" || true
          else
            echo "MQTT publish failed"
            
            # Notify Uptime Kuma of failure
            source ${config.sops.secrets."uptime-kuma.env".path}
            ${pkgs.curl}/bin/curl -s "$UPTIME_KUMA_INSTANCE_URL/api/push/B1hhLs9hts?status=down&msg=Failed&ping=" || true
          fi
        else
          echo "Temperature reading is empty"
          
          # Notify Uptime Kuma of failure
          source ${config.sops.secrets."uptime-kuma.env".path}
          ${pkgs.curl}/bin/curl -s "$UPTIME_KUMA_INSTANCE_URL/api/push/B1hhLs9hts?status=down&msg=Failed&ping=" || true
        fi
      else
        echo "Failed to read BME680 sensor: $temperature"
        
        # Notify Uptime Kuma of failure
        source ${config.sops.secrets."uptime-kuma.env".path}
        ${pkgs.curl}/bin/curl -s "$UPTIME_KUMA_INSTANCE_URL/api/push/B1hhLs9hts?status=down&msg=Failed&ping=" || true
      fi
      
      echo "BME680 cycle completed, sleeping 30 seconds..."
      ${pkgs.coreutils}/bin/sleep 30
    done
  '';
in
{
  sops = {
    secrets = {
      "mqtt.host" = {
        sopsFile = ./secrets.yaml;
      };
      "mqtt.topic.temperature" = {
        sopsFile = ./secrets.yaml;
      };
      "uptime-kuma.env" = {
        sopsFile = ../secrets.yaml;
      };
    };
  };
  systemd.user.services.bme680-mqtt = {
    Unit = {
      Description = "BME680 temperature sensor to MQTT";
      After = [ "network.target" ];
    };
    Service = {
      Type = "simple";
      Restart = "always";
      RestartSec = "10s";
      ExecStart = "${bme680-mqtt-loop}/bin/bme680-mqtt-loop";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
