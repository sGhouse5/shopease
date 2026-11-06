# Setup guide

Order matters: get each step green before the next. Check off as you go.

## 0. Plan the Azure resources

| VM | Role | Suggested size | Notes |
|---|---|---|---|
| `jenkins-vm` | Jenkins + Ansible + JDK 17 | 2 vCPU / 4 GB (for example B2s) | Jenkins is slow on 1 GB |
| `shop-staging` | Runs the app | at least 2 GB RAM (for example B1ms) | Spring Boot on 1 GB is tight |
| `shop-prod` (optional) | Runs the app | same | If you have no budget, point `production.ini` at the staging VM |

- Ubuntu 24.04 LTS on all VMs. Check the current Azure student credit and region availability before choosing sizes.
- **Create a budget alert first.** Stop (deallocate) VMs when not working.
- Firewall rules (network security group):
  - SSH 22: only from your IP, plus from `jenkins-vm` to the app VMs
  - Jenkins 8080 on `jenkins-vm`: your IP (and GitHub only if you use the webhook, see step 3)
  - App 8080 on the app VMs: your IP

## 1. SSH key for deployments

On your laptop:

```bash
ssh-keygen -t ed25519 -f shopease_vm -C "shopease-deploy"
```

- Put `shopease_vm.pub` as the admin SSH key when creating the **app** VMs (user `azureuser`).
- Keep `shopease_vm` (private) secret. It goes into Jenkins credentials only.
- Never commit either file. `.gitignore` does not cover arbitrary key names, so keep them outside the repo.

## 2. Install Jenkins on `jenkins-vm`

1. Install JDK 17, git and Ansible: `sudo apt update && sudo apt install -y openjdk-17-jdk git ansible`
2. Install Jenkins: copy `scripts/install-jenkins.sh` to the VM and run it (it prints the admin password). Official steps: https://www.jenkins.io/doc/book/installing/linux/
3. Open `http://<jenkins-vm-ip>:8080`, unlock with the initial admin password, install the suggested plugins.
4. Credentials: *Manage Jenkins > Credentials > Global > Add*
   - Kind: **SSH Username with private key**
   - ID: `shopease-vm-ssh` (must match the Jenkinsfile)
   - Username: `azureuser`
   - Private key: paste the contents of `shopease_vm`

## 3. Create the Jenkins job

- *New Item > Pipeline* (or Multibranch Pipeline).
- Pipeline from SCM: Git, your repo URL, branch `main`, script path `Jenkinsfile`.
- Run once manually with `DEPLOY_ENV = none` to confirm checkout, build, test, package work.
- Webhook: in GitHub repo *Settings > Webhooks*, payload URL `http://<jenkins-ip>:8080/github-webhook/`, content type `application/json`, push events. In the job enable "GitHub hook trigger for GITScm polling".
  - If you restricted port 8080 to your IP, GitHub cannot reach Jenkins. Either open it for the demo or use *Poll SCM* with `H/5 * * * *`.

## 4. Prepare the Ansible inventory

Edit `ansible/inventory/staging.ini` and `production.ini` with the VM IPs.
From `jenkins-vm`, prove SSH works before running Jenkins:

```bash
ssh -i shopease_vm azureuser@<staging-ip> hostname
```

## 5. First deployment

- Build with `DEPLOY_ENV = staging`.
- Open `http://<staging-ip>:8080`. The footer shows the version (`0.1.<build number>`).
- On the VM: `systemctl status shopease` and `ls /opt/shopease/releases`.

## 6. Test the rollback (important for the demo)

1. Make the app fail its health check on purpose (for example set a wrong datasource URL in `application-prod.properties`).
2. Push, run the pipeline with `staging`.
3. Expected: the Ansible health check fails, the old version is restored, the Jenkins build is red, the site still works on the old version.
4. Revert the change.

## 7. Azure DevOps

1. Create an organisation and a project at https://dev.azure.com.
2. **Boards:** create the backlog from `docs/BACKLOG.md` and run one sprint.
3. **Pipelines:** New pipeline > GitHub > select the repo > "Existing Azure Pipelines YAML file" > `azure-pipelines.yml`.
4. New organisations may have no free Microsoft-hosted parallel job until you request it, so a pipeline can sit "queued". If that happens, request the free grant (the error message links to the form) or use a self-hosted agent on a VM.

## Troubleshooting quick list

| Symptom | Likely cause |
|---|---|
| `gradlew: Permission denied` | Jenkinsfile already runs `chmod +x`; also run `git update-index --chmod=+x gradlew` |
| Jenkins cannot run `ansible-playbook` | Ansible not installed on `jenkins-vm`, or not on the `jenkins` user's PATH |
| `Permission denied (publickey)` | Wrong private key in credentials, or public key not on the app VM |
| Health check never turns UP | `journalctl -u shopease -n 100` on the app VM; check Java 17 and memory |
| Page unreachable from browser | App VM firewall rule for 8080 missing |
