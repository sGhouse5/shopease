@echo off
setlocal EnableDelayedExpansion
rem use-target.cmd - choose where the app is deployed.
rem   use-target.cmd local         run Jenkins and the app inside one WSL2 Ubuntu on this PC (no Azure needed)
rem   use-target.cmd azure         use the Azure VMs jenkins-vm and shop-staging in resource group shopease-rg
rem   use-target.cmd show          print the current inventory
rem   use-target.cmd reset-local   delete the local WSL environment
rem Run it from the project folder. The Jenkinsfile, playbook and SSH key never change between targets.

set "ROOT=%~dp0"
set "KEY=%USERPROFILE%\.ssh\shopease_vm"
set "MODE=%~1"
set SSHOPT=-o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL -i "%KEY%"

if /i "%MODE%"=="local" goto local
if /i "%MODE%"=="azure" goto azure
if /i "%MODE%"=="show" goto show
if /i "%MODE%"=="reset-local" goto resetlocal
echo Usage: use-target.cmd local ^| azure ^| show ^| reset-local
exit /b 1

:local
wsl --status >nul 2>&1
if !errorlevel! neq 0 (
  echo WSL is not ready. Open an Administrator CMD and run:  wsl --install --no-distribution
  echo Restart the PC, then run this again.
  exit /b 1
)
if not exist "%USERPROFILE%\.ssh" mkdir "%USERPROFILE%\.ssh"
if not exist "%KEY%.pub" ssh-keygen -t ed25519 -f "%KEY%" -N ""
wsl -d shopease -u root -- true >nul 2>&1
if !errorlevel! neq 0 (
  call :createdistro
  if !errorlevel! neq 0 exit /b 1
)
wsl -d shopease -u root -- test -d /var/lib/jenkins >nul 2>&1
if !errorlevel! neq 0 (
  call :installjenkins
  if !errorlevel! neq 0 exit /b 1
)
start "shopease-keepalive" /min wsl -d shopease -u root --exec sleep infinity
set "TARGET_HOST=127.0.0.1"
set "SSHUSER=deploy"
set "EXTRA=shop_port=8081"
set "JURL=http://localhost:8080"
set "SURL=http://localhost:8081"
echo.
echo Jenkins unlock password ^(only needed the first time^):
wsl -d shopease -u root -- cat /var/lib/jenkins/secrets/initialAdminPassword 2>nul
goto finish

:azure
where az >nul 2>&1
if !errorlevel! neq 0 (
  echo Azure CLI not found. Run: winget install -e --id Microsoft.AzureCLI
  exit /b 1
)
az account show >nul 2>&1
if !errorlevel! neq 0 (
  echo No Azure login or subscription. Run: az login
  exit /b 1
)
set "JENKINS_IP="
set "STAGING_IP="
for /f %%i in ('az vm show -d -g shopease-rg -n jenkins-vm --query publicIps -o tsv') do set "JENKINS_IP=%%i"
for /f %%i in ('az vm show -d -g shopease-rg -n shop-staging --query publicIps -o tsv') do set "STAGING_IP=%%i"
if not defined JENKINS_IP (
  echo Could not read the Azure VM addresses. Are the VMs created and started?
  exit /b 1
)
if not defined STAGING_IP (
  echo Could not read the Azure VM addresses. Are the VMs created and started?
  exit /b 1
)
set "SSHUSER=azureuser"
call :waitssh !JENKINS_IP! !SSHUSER!
if !errorlevel! neq 0 exit /b 1
call :ensurejenkins !JENKINS_IP! !SSHUSER!
set "TARGET_HOST=!STAGING_IP!"
set "EXTRA="
set "JURL=http://!JENKINS_IP!:8080"
set "SURL=http://!STAGING_IP!:8080"
goto finish

:show
if exist "%ROOT%ansible\inventory\staging.ini" type "%ROOT%ansible\inventory\staging.ini"
exit /b 0

:resetlocal
choice /c YN /m "Delete the local WSL environment (Jenkins settings and app data are lost)"
if errorlevel 2 exit /b 0
wsl --unregister shopease
echo Deleted. Run use-target.cmd local to create it again.
exit /b 0

:finish
> "%ROOT%ansible\inventory\staging.ini" (
  echo [app]
  echo shopease-staging ansible_host=!TARGET_HOST! ansible_user=!SSHUSER! !EXTRA!
)
copy /Y "%ROOT%ansible\inventory\staging.ini" "%ROOT%ansible\inventory\production.ini" >nul
echo.
echo Target:   %MODE%
echo Jenkins:  !JURL!
echo Shop:     !SURL!
git -C "%ROOT%." diff --quiet -- ansible/inventory
if !errorlevel! neq 0 (
  git -C "%ROOT%." add ansible/inventory
  git -C "%ROOT%." commit -m "Switch deploy target to %MODE%"
  git -C "%ROOT%." push
)
echo.
echo Done. If Jenkins is new on this target, do the Jenkins browser steps once: unlock, credential shopease-vm-ssh, job shopease.
exit /b 0

:createdistro
set "IMGNAME=ubuntu-24.04.5-wsl-amd64.wsl"
set "IMGDIR=%USERPROFILE%\wsl"
set "IMG=%IMGDIR%\%IMGNAME%"
if not exist "%IMGDIR%" mkdir "%IMGDIR%"
if not exist "%IMG%" if exist "%USERPROFILE%\Downloads\%IMGNAME%" copy /Y "%USERPROFILE%\Downloads\%IMGNAME%" "%IMG%" >nul
if not exist "%IMG%" (
  echo Downloading Ubuntu 24.04.5 for WSL - about 371 MB. It resumes by itself if the connection stalls.
  curl -fL -C - --retry 30 --retry-delay 5 --retry-all-errors --speed-limit 20000 --speed-time 30 -o "%IMG%.part" "https://releases.ubuntu.com/noble/%IMGNAME%"
  if !errorlevel! neq 0 (
    echo The download did not finish. Run this script again - it continues from where it stopped.
    exit /b 1
  )
  move /Y "%IMG%.part" "%IMG%" >nul
)
echo Checking the file against Ubuntu's published checksum...
set "WANT="
set "HAVE="
curl -fsSL -o "%TEMP%\SHA256SUMS" https://releases.ubuntu.com/noble/SHA256SUMS
for /f "tokens=1" %%h in ('findstr /c:"%IMGNAME%" "%TEMP%\SHA256SUMS" 2^>nul') do set "WANT=%%h"
for /f "skip=1 delims=" %%h in ('certutil -hashfile "%IMG%" SHA256') do if not defined HAVE set "HAVE=%%h"
set "HAVE=!HAVE: =!"
if defined WANT (
  if /i not "!HAVE!"=="!WANT!" (
    echo The downloaded file does not match Ubuntu's checksum. Deleting it - run this again.
    del "%IMG%"
    exit /b 1
  )
  echo Checksum OK.
) else (
  echo No published checksum found for this file - continuing without that check.
)
set "WSLDIR=%USERPROFILE%\wsl\shopease"
if not exist "%WSLDIR%" mkdir "%WSLDIR%"
echo Importing Ubuntu into WSL - a minute or two...
wsl --import shopease "%WSLDIR%" "%IMG%" --version 2
if !errorlevel! neq 0 (
  copy /Y "%IMG%" "%IMG%.tar.gz" >nul
  wsl --import shopease "%WSLDIR%" "%IMG%.tar.gz" --version 2
)
wsl -d shopease -u root -- true >nul 2>&1
if !errorlevel! neq 0 (
  echo Import failed. Read the message above.
  exit /b 1
)
echo Preparing the environment - user, ssh key, systemd...
wsl -d shopease -u root -- sh -c "cat > /tmp/shopease_vm.pub" < "%KEY%.pub"
wsl -d shopease -u root -- sh -c "cat > /tmp/wsl-stage1.sh" < "%ROOT%scripts\wsl-stage1.sh"
wsl -d shopease -u root -- bash /tmp/wsl-stage1.sh
if !errorlevel! neq 0 (
  echo Preparation failed. Read the message above, then run: use-target.cmd reset-local
  exit /b 1
)
wsl --terminate shopease
timeout /t 3 >nul
exit /b 0

:installjenkins
echo Installing Jenkins inside the local environment - several minutes...
wsl -d shopease -u root -- sh -c "cat > /tmp/wsl-stage2.sh" < "%ROOT%scripts\wsl-stage2.sh"
wsl -d shopease -u root -- sh -c "cat > /tmp/install-jenkins.sh" < "%ROOT%scripts\install-jenkins.sh"
wsl -d shopease -u root -- bash /tmp/wsl-stage2.sh
if !errorlevel! neq 0 (
  echo Jenkins install failed. Read the messages above.
  exit /b 1
)
exit /b 0

:waitssh
set /a N=0
:waitloop
ssh %SSHOPT% %2@%1 true >nul 2>&1
if !errorlevel! equ 0 exit /b 0
set /a N+=1
if !N! GEQ 36 (
  echo Could not SSH to %1
  exit /b 1
)
timeout /t 5 >nul
goto waitloop

:ensurejenkins
ssh %SSHOPT% %2@%1 "test -d /var/lib/jenkins" >nul 2>&1
if !errorlevel! neq 0 (
  echo Installing Jenkins on %1 - this takes several minutes...
  scp %SSHOPT% "%ROOT%scripts\install-jenkins.sh" %2@%1:~/
  ssh %SSHOPT% %2@%1 "bash ~/install-jenkins.sh"
)
exit /b 0
