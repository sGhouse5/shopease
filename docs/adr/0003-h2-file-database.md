# ADR 0003: H2 file database for the demo

- Status: Accepted
- Date: 2026-11-06

## Decision
Use an embedded H2 database stored in `/opt/shopease/data` on the app VM.

## Why
- No extra server to install, pay for or secure.
- Data survives restarts and redeploys because it lives outside the release folders.

## Consequences
- Not suitable for several app instances or real production use.
- Moving to MySQL/PostgreSQL means changing the datasource URL and adding a database role to Ansible.
