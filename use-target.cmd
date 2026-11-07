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
if errorlevel 1 (
  echo WSL is not ready. Open an Administrator CMD and run:  wsl --install --no-distribution
  echo Restart the PC, then run this again.
  exit /b 1
)
if not exist "%USERPROFILE%\.ssh" mkdir "%USERPROFILE%\.ssh"
if not exist "%KEY%.pub" ssh-keygen -t ed25519 -f "%KEY%" -N ""
wsl -d shopease -u root -- true >nul 2>&1
if errorlevel 1 (
  call :createdistro
  if errorlevel 1 exit /b 1
)
wsl -d shopease -u root -- test -d /var/lib/jenkins >nul 2>&1
if errorlevel 1 (
  call :installjenkins
  if errorlevel 1 exit /b 1
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
if errorlevel 1 (
  echo Azure CLI not found. Run: winget install -e --id Microsoft.AzureCLI
  exit /b 1
)
az account show >nul 2>&1
if errorlevel 1 (
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
if errorlevel 1 exit /b 1
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
if exist "%USERPROFILE%\wsl\shopease" rmdir /s /q "%USERPROFILE%\wsl\shopease"
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
if errorlevel 1 (
  git -C "%ROOT%." add ansible/inventory
  git -C "%ROOT%." commit -m "Switch deploy target to %MODE%"
  git -C "%ROOT%." push
)
echo.
echo Done. If Jenkins is new on this target, do the Jenkins browser steps once: unlock, credential shopease-vm-ssh, job shopease.
exit /b 0

:createdistro
set "TAR=%TEMP%\ubuntu-noble-wsl.tar.gz"
if not exist "%TAR%" (
  echo Downloading Ubuntu 24.04 for WSL - about 350 MB...
  set "GOT="
  for %%U in (wsl ubuntu ubuntu24.04lts) do if not defined GOT (
    curl -fL -o "%TAR%.part" "https://cloud-images.ubuntu.com/wsl/noble/current/ubuntu-noble-wsl-amd64-%%U.rootfs.tar.gz" && set "GOT=1"
  )
  if defined GOT move /Y "%TAR%.part" "%TAR%" >nul
)
if not exist "%TAR%" (
  echo Download failed. Check your internet connection and run this again.
  exit /b 1
)
set "WSLDIR=%USERPROFILE%\wsl\shopease"
if not exist "%WSLDIR%" mkdir "%WSLDIR%"
echo Importing the Ubuntu image into WSL...
wsl --import shopease "%WSLDIR%" "%TAR%" --version 2
if errorlevel 1 (
  echo Import failed. Read the message above.
  exit /b 1
)
echo Preparing the environment - user, ssh key, systemd...
wsl -d shopease -u root -- sh -c "cat > /tmp/shopease_vm.pub" < "%KEY%.pub"
wsl -d shopease -u root -- sh -c "cat > /tmp/wsl-stage1.sh" < "%ROOT%scripts\wsl-stage1.sh"
wsl -d shopease -u root -- bash /tmp/wsl-stage1.sh
if errorlevel 1 (
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
if errorlevel 1 (
  echo Jenkins install failed. Read the messages above.
  exit /b 1
)
exit /b 0

:waitssh
set /a N=0
:waitloop
ssh %SSHOPT% %2@%1 true >nul 2>&1
if not errorlevel 1 exit /b 0
set /a N+=1
if !N! GEQ 36 (
  echo Could not SSH to %1
  exit /b 1
)
timeout /t 5 >nul
goto waitloop

:ensurejenkins
ssh %SSHOPT% %2@%1 "test -d /var/lib/jenkins" >nul 2>&1
if errorlevel 1 (
  echo Installing Jenkins on %1 - this takes several minutes...
  scp %SSHOPT% "%ROOT%scripts\install-jenkins.sh" %2@%1:~/
  ssh %SSHOPT% %2@%1 "bash ~/install-jenkins.sh"
)
exit /b 0
