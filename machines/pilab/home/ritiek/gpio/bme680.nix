{ config, pkgs, lib, inputs, enableLEDs, ... }:

let
  bme680Script = pkgs.writeText "bme680_reader.py" ''
    #!/usr/bin/env python3
    import bme680
    import time
    import sys
    import json

    try:
        sensor = bme680.BME680(bme680.I2C_ADDR_PRIMARY)
    except (RuntimeError, IOError):
        sensor = bme680.BME680(bme680.I2C_ADDR_SECONDARY)

    sensor.set_humidity_oversample(bme680.OS_2X)
    sensor.set_pressure_oversample(bme680.OS_4X)
    sensor.set_temperature_oversample(bme680.OS_8X)
    sensor.set_filter(bme680.FILTER_SIZE_3)
    sensor.set_gas_status(bme680.ENABLE_GAS_MEAS)

    sensor.set_gas_heater_temperature(320)
    sensor.set_gas_heater_duration(150)
    sensor.select_gas_heater_profile(0)

    # Wait for sensor data and gas heater to stabilize
    # Gas heater takes longer to stabilize, so we read temp/pressure/humidity immediately
    # but wait longer for gas resistance
    attempts = 0
    max_attempts = 10
    gas_resistance = None

    while attempts < max_attempts:
        if sensor.get_sensor_data():
            data = {
                'temperature': round(sensor.data.temperature, 2),
                'pressure': round(sensor.data.pressure, 2),
                'humidity': round(sensor.data.humidity, 2),
                'gas_resistance': sensor.data.gas_resistance if sensor.data.heat_stable else None
            }

            # If we have basic readings, output them even if gas isn't stable yet
            if attempts >= 2:  # Give it at least 2 seconds
                print(json.dumps(data), end="")
                sys.exit(0)

        attempts += 1
        time.sleep(1)

    print("Failed to read sensor data after retries", file=sys.stderr)
    sys.exit(1)
  '';

  bme680-mqtt-loop = pkgs.writeShellScriptBin "bme680-mqtt-loop" ''
    echo "BME680 continuous service starting..."

    # State file for air quality baseline
    STATE_FILE="/var/lib/bme680/iaq_state.json"
    ${pkgs.coreutils}/bin/mkdir -p /var/lib/bme680

    # Initialize or load state
    if [ ! -f "$STATE_FILE" ]; then
      echo '{"gas_baseline": null, "burn_in_data": [], "burn_in_complete": false}' > "$STATE_FILE"
    fi

    # Function to handle failures
    handle_failure() {
      # Notify Uptime Kuma of failure
      source ${config.sops.secrets."uptime-kuma.env".path}
      ${pkgs.curl}/bin/curl -s "$UPTIME_KUMA_INSTANCE_URL/api/push/B1hhLs9hts?status=down&msg=Failed&ping=" || true

      ${lib.optionalString enableLEDs ''
      # Blink Red LED on failure
      ${pkgs.libgpiod}/bin/gpioset -t 0 -c gpiochip0 27=1
      ${pkgs.coreutils}/bin/sleep 0.4s
      ${pkgs.libgpiod}/bin/gpioset -t 0 -c gpiochip0 27=0
      ''}
    }

    while true; do
      echo ""
      echo "BME680 reading cycle starting..."

      # Try to read sensor data with detailed error output
      if sensor_data=$(${pkgs.python3.withPackages (ps: with ps; [ bme680 ])}/bin/python ${bme680Script} 2>&1); then
        if [ -n "$sensor_data" ]; then
          # Parse JSON data
          temperature=$(echo "$sensor_data" | ${pkgs.jq}/bin/jq -r '.temperature')
          pressure=$(echo "$sensor_data" | ${pkgs.jq}/bin/jq -r '.pressure')
          humidity=$(echo "$sensor_data" | ${pkgs.jq}/bin/jq -r '.humidity')
          gas_resistance=$(echo "$sensor_data" | ${pkgs.jq}/bin/jq -r '.gas_resistance')

          # Format gas resistance to 2 decimal places for logging
          gas_resistance_formatted=$(printf "%.2f" "$gas_resistance")

          echo "Sensor readings: Temp=$temperature°C, Pressure=$pressure hPa, Humidity=$humidity%, Gas=$gas_resistance_formatted Ohms"

          # Read MQTT configuration
          mqtt_hosts_content=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."mqtt.hosts".path})
          mqtt_topic_base=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."mqtt.topic.base".path})

          # Calculate Air Quality Score (if gas resistance is available)
          air_quality=""
          if [ "$gas_resistance" != "null" ] && [ -n "$gas_resistance" ]; then
            state=$(${pkgs.coreutils}/bin/cat "$STATE_FILE")
            gas_baseline=$(echo "$state" | ${pkgs.jq}/bin/jq -r '.gas_baseline')
            burn_in_complete=$(echo "$state" | ${pkgs.jq}/bin/jq -r '.burn_in_complete')

            if [ "$burn_in_complete" = "false" ]; then
              # Collect burn-in data (first 10 readings with stable gas)
              burn_in_data=$(echo "$state" | ${pkgs.jq}/bin/jq -r '.burn_in_data | length')
              if [ "$burn_in_data" -lt 10 ]; then
                echo "  Collecting IAQ burn-in data: $burn_in_data/10"
                state=$(echo "$state" | ${pkgs.jq}/bin/jq ".burn_in_data += [$gas_resistance]")
                echo "$state" > "$STATE_FILE"
              else
                # Calculate baseline as average of last 10 readings
                gas_baseline=$(echo "$state" | ${pkgs.jq}/bin/jq '[.burn_in_data[-10:]] | add / length')
                state=$(echo "$state" | ${pkgs.jq}/bin/jq ".gas_baseline = $gas_baseline | .burn_in_complete = true")
                echo "$state" > "$STATE_FILE"
                echo "  ✓ IAQ baseline established: $gas_baseline Ohms"
              fi
            else
              # Calculate IAQ score
              hum_baseline=40.0
              hum_weighting=0.25

              # Calculate humidity score
              hum_offset=$(echo "$humidity - $hum_baseline" | ${pkgs.bc}/bin/bc -l)
              if (( $(echo "$hum_offset > 0" | ${pkgs.bc}/bin/bc -l) )); then
                hum_score=$(echo "(100 - $hum_baseline - $hum_offset) / (100 - $hum_baseline) * ($hum_weighting * 100)" | ${pkgs.bc}/bin/bc -l)
              else
                hum_score=$(echo "($hum_baseline + $hum_offset) / $hum_baseline * ($hum_weighting * 100)" | ${pkgs.bc}/bin/bc -l)
              fi

              # Calculate gas score
              gas_offset=$(echo "$gas_baseline - $gas_resistance" | ${pkgs.bc}/bin/bc -l)
              if (( $(echo "$gas_offset > 0" | ${pkgs.bc}/bin/bc -l) )); then
                gas_score=$(echo "($gas_resistance / $gas_baseline) * (100 - ($hum_weighting * 100))" | ${pkgs.bc}/bin/bc -l)
              else
                gas_score=$(echo "100 - ($hum_weighting * 100)" | ${pkgs.bc}/bin/bc -l)
              fi

              # Total air quality score (0-100, higher is better)
              air_quality=$(printf "%.2f" $(echo "$hum_score + $gas_score" | ${pkgs.bc}/bin/bc -l))
              echo "  ✓ Air Quality Score: $air_quality/100"
            fi
          fi

          # Publish to all MQTT brokers
          publish_success=false
          while IFS= read -r mqtt_host_port; do
            [ -z "$mqtt_host_port" ] && continue
            mqtt_host=$(echo "$mqtt_host_port" | ${pkgs.coreutils}/bin/cut -d: -f1)
            mqtt_port=$(echo "$mqtt_host_port" | ${pkgs.coreutils}/bin/cut -d: -f2)

            echo "Publishing to MQTT broker: $mqtt_host:$mqtt_port"

            # Publish temperature
            if echo "$temperature" | ${pkgs.mosquitto}/bin/mosquitto_pub -h "$mqtt_host" -p "$mqtt_port" -t "$mqtt_topic_base-temp" -l; then
              echo "  ✓ Temperature published to $mqtt_topic_base-temp"
              publish_success=true
            fi

            # Publish pressure
            if echo "$pressure" | ${pkgs.mosquitto}/bin/mosquitto_pub -h "$mqtt_host" -p "$mqtt_port" -t "$mqtt_topic_base-pressure" -l; then
              echo "  ✓ Pressure published to $mqtt_topic_base-pressure"
            fi

            # Publish humidity
            if echo "$humidity" | ${pkgs.mosquitto}/bin/mosquitto_pub -h "$mqtt_host" -p "$mqtt_port" -t "$mqtt_topic_base-humidity" -l; then
              echo "  ✓ Humidity published to $mqtt_topic_base-humidity"
            fi

            # Publish gas resistance (if available)
            if [ "$gas_resistance" != "null" ] && [ -n "$gas_resistance" ]; then
              if echo "$gas_resistance" | ${pkgs.mosquitto}/bin/mosquitto_pub -h "$mqtt_host" -p "$mqtt_port" -t "$mqtt_topic_base-gas" -l; then
                echo "  ✓ Gas resistance published to $mqtt_topic_base-gas"
              fi
            fi

            # Publish air quality (if calculated)
            if [ -n "$air_quality" ]; then
              if echo "$air_quality" | ${pkgs.mosquitto}/bin/mosquitto_pub -h "$mqtt_host" -p "$mqtt_port" -t "$mqtt_topic_base-airquality" -l; then
                echo "  ✓ Air quality published to $mqtt_topic_base-airquality"
              fi
            fi

          done <<< "$mqtt_hosts_content"

          echo "  ✓ All sensors published"
          publish_success=true

          if [ "$publish_success" = true ]; then
            # Notify Uptime Kuma of success
            source ${config.sops.secrets."uptime-kuma.env".path}
            ${pkgs.curl}/bin/curl -s "$UPTIME_KUMA_INSTANCE_URL/api/push/B1hhLs9hts?status=up&msg=OK&ping=" || true

            ${lib.optionalString enableLEDs ''
            # Blink Green LED on success
            ${pkgs.libgpiod}/bin/gpioset -t 0 -c gpiochip0 5=1
            ${pkgs.coreutils}/bin/sleep 0.4s
            ${pkgs.libgpiod}/bin/gpioset -t 0 -c gpiochip0 5=0
            ''}
          else
            echo "All MQTT publish attempts failed"
            handle_failure
          fi
        else
          echo "Sensor reading is empty"
          handle_failure
        fi
      else
        echo "Failed to read BME680 sensor: $sensor_data"
        handle_failure
      fi

      echo "BME680 cycle completed, sleeping 60 seconds..."
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
