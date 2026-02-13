# ADR-002: Single-Table DynamoDB Design

**Status**: Accepted  
**Date**: 2026-02-12

## Context

ShipZero manages multiple entity types: Users, Projects, Deployments, Environment Variables, Domains, and Build deduplication records. Relational databases add cost and operational overhead (RDS minimum ~$15/month).

## Decision

Use a **single DynamoDB table** with composite `PK/SK` keys and one GSI (`GSI1PK/GSI1SK`) for alternate access patterns.

## Key Design

- **PK/SK**: Primary access (user's projects, project's deployments)
- **GSI1PK/GSI1SK**: Alternate lookups (project by ID, deployment by ID, domain lookup)
- **Billing**: `PAY_PER_REQUEST` (on-demand) — no provisioned capacity

## Consequences

- All entities share one table — reduces cost and operational complexity
- Access patterns must be designed up-front (see [ARCHITECTURE.md](../ARCHITECTURE.md))
- Adding new access patterns may require adding a GSI (max 20 per table, but we're unlikely to need more than 2–3)
- Reads of individual items are efficient; complex aggregations should be avoided at the DB layer
