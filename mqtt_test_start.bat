@echo off
cd "C:\Program Files\mosquitto"
mosquitto_pub.exe -h 127.0.0.1 -t "erd/drugslab/station-a/start" -f "%~dp0test_start.json"
echo Game start message sent!
pause
