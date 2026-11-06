# ADR 0004: Keep carts in memory

- Status: Accepted
- Date: 2026-11-06

## Decision
Carts are held in a map keyed by a cart id the browser generates.

## Why
- The project is about the delivery pipeline, not shopping features.
- Fewer tables and less code to maintain.

## Consequences
- Carts disappear on restart or redeploy. Orders and products are stored in the database.
- Revisit if time remains (store carts in the database).
