#!/usr/bin/env bash
# Runs as root inside the "shopease" WSL distro, once, right after import.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y sudo openssh-server curl wget git ca-certificates

# Deploy user that Ansible logs in as (key only, passwordless sudo).
id deploy >/dev/null 2>&1 || useradd -m -s /bin/bash deploy
echo 'deploy ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/deploy
chmod 440 /etc/sudoers.d/deploy
install -d -m 700 -o deploy -g deploy /home/deploy/.ssh
install -m 600 -o deploy -g deploy /tmp/shopease_vm.pub /home/deploy/.ssh/authorized_keys

# Turn on systemd so services (ssh, jenkins, shopease) work like on a real VM.
cat > /etc/wsl.conf <<'CONF'
[boot]
systemd=true

[user]
default=deploy
CONF

echo "Stage 1 done."
