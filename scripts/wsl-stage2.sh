#!/usr/bin/env bash
# Runs as root inside the distro after it restarted with systemd enabled.
set -euo pipefail

state=""
for i in $(seq 1 60); do
  state=$(systemctl is-system-running 2>/dev/null || true)
  if [ "$state" = "running" ] || [ "$state" = "degraded" ]; then break; fi
  sleep 2
done
if [ "$state" != "running" ] && [ "$state" != "degraded" ]; then
  echo "systemd did not start inside the distro (state: $state)."
  exit 1
fi

systemctl enable --now ssh
bash /tmp/install-jenkins.sh
