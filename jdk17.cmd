@echo off
rem Project-local Java 17, like a venv. Usage (from the project folder):  call jdk17.cmd
rem It changes JAVA_HOME and PATH for THIS CMD window only. Your system Java stays untouched.
setlocal
set "HERE=%~dp0"

if not exist "%HERE%.jdk17\" (
  echo Downloading Temurin JDK 17 into .jdk17 - one time, about 190 MB...
  mkdir "%HERE%.jdk17"
  curl -L -o "%HERE%.jdk17\jdk.zip" "https://api.adoptium.net/v3/binary/latest/17/ga/windows/x64/jdk/hotspot/normal/eclipse"
  tar -xf "%HERE%.jdk17\jdk.zip" -C "%HERE%.jdk17"
  del "%HERE%.jdk17\jdk.zip"
)

set "JDK="
for /d %%d in ("%HERE%.jdk17\jdk-17*") do set "JDK=%%d"
if not defined JDK (
  echo JDK 17 was not found inside .jdk17. Delete the .jdk17 folder and run this again.
  exit /b 1
)

endlocal & set "JAVA_HOME=%JDK%" & set "PATH=%JDK%\bin;%PATH%"
java -version
