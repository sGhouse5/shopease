# Everything to run, in order (Windows CMD)

Replace YOUR_NAME, YOUR_EMAIL, YOUR_ORG. Variables last only for the current CMD window, so use one window.
Only three things cannot be commands (marked GUI): the Jenkins first-run screen, one Jenkins credential, one Jenkins job.

## 1. Install tools (once; then close and reopen CMD)
```
winget install -e --id EclipseAdoptium.Temurin.17.JDK
winget install -e --id Git.Git
winget install -e --id GitHub.cli
winget install -e --id Microsoft.AzureCLI
```
```
java -version
git --version
gh --version
az --version
git config --global user.name "YOUR_NAME"
git config --global user.email "YOUR_EMAIL"
```

## 2. Unzip and create the Gradle wrapper
```
cd %USERPROFILE%\Downloads
tar -xf shopease-devops-starter.zip
cd shopease
set PROJ=%CD%
mkdir %TEMP%\wrap
cd /d %TEMP%\wrap
curl -L https://start.spring.io/starter.zip -d type=gradle-project -d language=java -d dependencies=web -o w.zip
tar -xf w.zip
gradlew.bat wrapper --gradle-version 8.14
xcopy /E /I /Y gradle "%PROJ%\gradle"
copy /Y gradlew "%PROJ%"
copy /Y gradlew.bat "%PROJ%"
cd /d %PROJ%
```

## 3. Test and run locally
```
gradlew.bat test
gradlew.bat bootRun
```
Open http://localhost:8080 , then Ctrl+C to stop.

## 4. GitHub repo and issues
```
git init -b main
git add .
git update-index --chmod=+x gradlew
git commit -m "Initial ShopEase pipeline project"
gh auth login
gh repo create shopease --public --source=. --remote=origin --push
for /f %i in ('gh api user --jq .login') do set GHUSER=%i
gh issue create -t "Shopper can see products" -b "Product list on the home page"
gh issue create -t "Shopper can add products to a cart" -b "Cart API and page"
gh issue create -t "Shopper can check out" -b "Order number returned"
gh issue create -t "Cannot buy more than stock" -b "Stock check at checkout"
gh issue create -t "Admin can add a product" -b "POST /api/products"
gh issue create -t "Deployed version visible on page" -b "Footer shows /actuator/info"
```

## 5. Azure VMs
```
az login
az group create -n shopease-rg -l centralindia
ssh-keygen -t ed25519 -f %USERPROFILE%\.ssh\shopease_vm -N ""
az vm create -g shopease-rg -n jenkins-vm --image Canonical:ubuntu-24_04-lts:server:latest --size Standard_B2s --admin-username azureuser --ssh-key-values %USERPROFILE%\.ssh\shopease_vm.pub --public-ip-sku Standard
az vm create -g shopease-rg -n shop-staging --image Canonical:ubuntu-24_04-lts:server:latest --size Standard_B1ms --admin-username azureuser --ssh-key-values %USERPROFILE%\.ssh\shopease_vm.pub --public-ip-sku Standard
```
If a size is not available: `az vm list-skus -l centralindia --size Standard_B -o table` and pick another, or change the region.

Firewall (Jenkins UI only from your IP; the app is open for the demo):
```
for /f %i in ('curl -s https://api.ipify.org') do set MYIP=%i
az network nsg rule create -g shopease-rg --nsg-name jenkins-vmNSG -n allow-jenkins-ui --priority 1010 --destination-port-ranges 8080 --source-address-prefixes %MYIP% --access Allow --protocol Tcp
az vm open-port -g shopease-rg -n shop-staging --port 8080 --priority 1010
```
(If your IP changes, for example on a hotspot, re-run these two lines with the new IP. If the NSG name differs: `az network nsg list -g shopease-rg -o table`.)

Put the VM addresses into the inventory and push:
```
for /f %i in ('az vm show -d -g shopease-rg -n jenkins-vm --query publicIps -o tsv') do set JENKINS_IP=%i
for /f %i in ('az vm show -d -g shopease-rg -n shop-staging --query publicIps -o tsv') do set STAGING_IP=%i
echo %JENKINS_IP% %STAGING_IP%
(echo [app]& echo shopease-staging ansible_host=%STAGING_IP% ansible_user=azureuser)> ansible\inventory\staging.ini
copy /Y ansible\inventory\staging.ini ansible\inventory\production.ini
git add ansible
git commit -m "Set VM addresses"
git push
```

## 6. Install Jenkins on the VM
```
scp -o StrictHostKeyChecking=accept-new -i %USERPROFILE%\.ssh\shopease_vm scripts\install-jenkins.sh azureuser@%JENKINS_IP%:~/
ssh -i %USERPROFILE%\.ssh\shopease_vm azureuser@%JENKINS_IP% "bash ~/install-jenkins.sh"
```
It ends by printing the initial admin password.

**GUI 1:** open `http://<JENKINS_IP>:8080` (`echo %JENKINS_IP%`), paste the password, Install suggested plugins, create the admin user.

**GUI 2:** run `type %USERPROFILE%\.ssh\shopease_vm | clip` , then Jenkins > Manage Jenkins > Credentials > System > Global > Add credentials:
Kind = SSH Username with private key, ID = `shopease-vm-ssh`, Username = `azureuser`, Private Key > Enter directly > Add > paste.

**GUI 3:** New Item > name `shopease` > Pipeline > OK > Pipeline script from SCM > Git > Repository URL = output of `echo https://github.com/%GHUSER%/shopease.git` > Branch `*/main` > Script Path `Jenkinsfile` > Save.

Then press **Build Now** once. (The first run only builds and tests; it registers the parameter.)
Then **Build with Parameters** > `staging`.

## 7. Check the deployment
```
curl http://%STAGING_IP%:8080/actuator/health
curl http://%STAGING_IP%:8080/api/products
start http://%STAGING_IP%:8080
ssh -i %USERPROFILE%\.ssh\shopease_vm azureuser@%STAGING_IP% "systemctl status shopease --no-pager; ls /opt/shopease/releases"
```

## 8. Prove automatic deploy and rollback (the demo)
Normal change (Jenkins polls GitHub every ~2 minutes and deploys to staging):
```
echo ^<!-- change --^>>> src\main\resources\static\index.html
git commit -am "Small visible change"
git push
```
Deliberately broken build:
```
echo spring.datasource.url=jdbc:h2:tcp://localhost:1/none>> src\main\resources\application-prod.properties
git commit -am "TEST: break datasource on purpose"
git push
```
Expect a red Jenkins build, an Ansible rollback message, and the site still on the old version. Repair:
```
git revert --no-edit HEAD
git push
```

## 9. Azure DevOps
Browser, once: create an organisation at https://aex.dev.azure.com , then User settings > Personal access tokens > New (Full access, 30 days) and copy it.
```
az extension add --name azure-devops
set ORG=https://dev.azure.com/YOUR_ORG
az devops configure --defaults organization=%ORG%
az devops login --organization %ORG%
az devops project create --name shopease
az devops configure --defaults project=shopease
for /f %t in ('gh auth token') do set AZURE_DEVOPS_EXT_GITHUB_PAT=%t
for /f %i in ('az devops service-endpoint github create --github-url https://github.com/%GHUSER%/shopease --name github-conn --query id -o tsv') do set SC_ID=%i
az pipelines create --name shopease-ci --repository https://github.com/%GHUSER%/shopease --repository-type github --branch main --yml-path azure-pipelines.yml --service-connection %SC_ID%
for %t in ("Shopper can see products" "Shopper can add to cart" "Shopper can check out" "Stock check at checkout" "Admin can add a product" "Version visible on page") do az boards work-item create --title %~t --type "User Story" -o none
```
(If the work-item type fails, your project uses the Basic process: replace `"User Story"` with `"Issue"`. If `az pipelines create` fails, create the pipeline in the browser: Pipelines > New > GitHub > Existing YAML file. A new organisation may need the free parallel-job request before the first run.)

## 10. Save credit and clean up
Stop for the night (IPs stay the same):
```
az vm deallocate -g shopease-rg -n jenkins-vm --no-wait
az vm deallocate -g shopease-rg -n shop-staging --no-wait
```
Start again:
```
az vm start -g shopease-rg -n jenkins-vm --no-wait
az vm start -g shopease-rg -n shop-staging --no-wait
```
Delete everything after submission:
```
az group delete -n shopease-rg --yes --no-wait
```
Set a budget alert once in the portal: Cost Management + Billing > Budgets.
