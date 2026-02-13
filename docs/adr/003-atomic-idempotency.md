# ADR-003: Atomic Webhook Idempotency

**Status**: Accepted  
**Date**: 2026-02-12

## Context

GitHub can deliver the same webhook event multiple times (retries, network issues). If each delivery triggers a build, we get duplicate builds that waste CodeBuild minutes and corrupt deployment state.

## Decision

Use a single **DynamoDB `PutItem` with `ConditionExpression: attribute_not_exists(PK)`** as the idempotency gate.

## Mechanism

- **Key**: `PK = "BUILD#PROJECT#{projectId}#COMMIT#{commitSha}"`, `SK = "METADATA"`
- **On success**: Emit `BuildRequested` event
- **On `ConditionalCheckFailedException`**: Return 200 OK, do nothing

## Why Not Check-Then-Write

A "read first, then write" approach has a race condition: two concurrent Lambda invocations can both read "not exists" and both emit events. The conditional `PutItem` is atomic — DynamoDB guarantees exactly one will succeed.

## Consequences

- Manual redeploys use a different key pattern (`BUILD#PROJECT#{id}#ATTEMPT#{n}`)
- Build deduplication records accumulate in DynamoDB (low cost at on-demand pricing)
- If we need to force-rebuild the same commit, the user triggers via the API endpoint (different key)
