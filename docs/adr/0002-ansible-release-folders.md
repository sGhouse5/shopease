# ADR 0002: Deploy with Ansible into release folders and a symlink

- Status: Accepted
- Date: 2026-11-06

## Decision
Each deployment copies the jar to `/opt/shopease/releases/<build>/` and moves the `current` symlink.
The playbook checks `/actuator/health` and moves the symlink back if it fails.

## Why
- Rolling back is a symlink change plus a restart, not a rebuild.
- Several old releases stay on disk (the newest three are kept).
- The playbook is repeatable: running it twice gives the same result.

## Rejected
- Shell scripts over SSH: not repeatable, no clear change reporting.
- Overwriting one jar in place: no quick way back.
