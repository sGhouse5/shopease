#!/usr/bin/env bash
# Run on the Jenkins VM (Ubuntu 24.04). Installs Java 17, git, Ansible and Jenkins LTS.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

sudo apt-get update
sudo apt-get install -y openjdk-17-jdk git ansible fontconfig wget

sudo mkdir -p /etc/apt/keyrings
# Key name changes over time. If this URL fails, copy the current lines from
# https://www.jenkins.io/doc/book/installing/linux/
sudo wget -O /etc/apt/keyrings/jenkins-keyring.asc https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key
echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" \
  | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null

sudo apt-get update
sudo apt-get install -y jenkins
sudo systemctl enable --now jenkins

echo "Waiting for Jenkins to create its admin password..."
for i in $(seq 1 60); do
  if sudo test -f /var/lib/jenkins/secrets/initialAdminPassword; then break; fi
  sleep 5
done

echo
echo "==== Jenkins is installed. Initial admin password: ===="
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
echo "==== Open http://<this-vm-public-ip>:8080 and paste it. ===="
ansible --version | head -1
java -version 2>&1 | head -1
