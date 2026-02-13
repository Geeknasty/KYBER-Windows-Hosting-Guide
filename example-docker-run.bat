docker run ^
  -e MAXIMA_CREDENTIALS="<EA-Username>:<password>" ^
  -e KYBER_TOKEN=<token> ^
  -e KYBER_SERVER_NAME="<server-name>" ^
  -e KYBER_SERVER_MAX_PLAYERS=40 ^
  -e KYBER_MAP_ROTATION="<base64-encoded‐map‐rotation>" ^
  -e KYBER_MOD_FOLDER=/mnt/battlefront/mods ^
  -v "<swbf2_data_volume>:/mnt/battlefront" ^
  -v "<swbf2_mods_gamemode_volume>:/mnt/battlefront/mods" ^
  -v "./logs/:/root/.local/share/maxima/wine/prefix/drive_c/users/root/AppData/Roaming/ArmchairDevelopers/Kyber/Logs/" ^
  -it ^
  ghcr.io/armchairdevelopers/kyber-server:latest

:: Logs will be output to the logs folder in the same location as this .bat file