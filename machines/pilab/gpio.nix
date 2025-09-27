{ config, pkgs, lib, ... }:

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
        # output = '{0:.2f} C,{1:.2f} hPa,{2:.3f} %RH'.format(
        #     sensor.data.temperature,
        #     sensor.data.pressure,
        #     sensor.data.humidity)
        output = '{0:.2f}'.format(sensor.data.temperature)
        print(output, end="")
    else:
        print("Failed to read sensor data", file=sys.stderr)
        sys.exit(1)
  '';
in
{
  sops.secrets."mqtt.host" = {};
  sops.secrets."mqtt.topic.temperature" = {};

  systemd.services.bme680-mqtt = {
    description = "BME680 temperature sensor to MQTT";
    after = [ "network.target" ];
    
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      
      ExecStart = pkgs.writeShellScript "bme680-mqtt" ''
        if temperature=$(${pkgs.python3.withPackages (ps: with ps; [ bme680 ])}/bin/python ${bme680Script} 2>/dev/null); then
          ${pkgs.coreutils}/bin/echo "Temperature reading: $temperature°C"
          mqtt_host_port=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."mqtt.host".path})
          mqtt_host=$(${pkgs.coreutils}/bin/echo "$mqtt_host_port" | ${pkgs.coreutils}/bin/cut -d: -f1)
          mqtt_port=$(${pkgs.coreutils}/bin/echo "$mqtt_host_port" | ${pkgs.coreutils}/bin/cut -d: -f2)
          mqtt_topic_temperature=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."mqtt.topic.temperature".path})
          ${pkgs.coreutils}/bin/echo "$temperature" | ${pkgs.mosquitto}/bin/mosquitto_pub -h "$mqtt_host" -p "$mqtt_port" -t "$mqtt_topic_temperature" -l
        else
          ${pkgs.coreutils}/bin/echo "Failed to read BME680 sensor - skipping MQTT publish"
          exit 1
        fi
      '';
    };
  };

  systemd.timers.bme680-mqtt = {
    description = "Run BME680 sensor reading every 30 seconds";
    wantedBy = [ "timers.target" ];
    
    timerConfig = {
      OnBootSec = "30s";
      OnUnitActiveSec = "30s";
      Unit = "bme680-mqtt.service";
    };
  };
}
