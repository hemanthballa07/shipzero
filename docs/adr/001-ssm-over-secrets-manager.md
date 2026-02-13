# ADR-001: SSM Parameter Store over Secrets Manager

**Status**: Accepted  
**Date**: 2026-02-12

## Context

ShipZero needs to store 3–4 GitHub App secrets (webhook secret, private key PEM, app ID, installation ID). Both AWS Secrets Manager and SSM Parameter Store support `SecureString` encryption via KMS.

## Decision

Use **SSM Parameter Store (Standard Tier)** for all secrets.

## Rationale

| Factor | Secrets Manager | SSM Parameter Store |
|---|---|---|
| Cost | $0.40/secret/month ($1.20 for 3) | Free (Standard, up to 10K) |
| Encryption | KMS (default key) | KMS (default key) |
| Rotation | Built-in | Manual / Lambda |
| API | GetSecretValue | GetParameter |
| Terraform | `data "aws_secretsmanager_secret"` | `data "aws_ssm_parameter"` |

We don't need automatic rotation — secrets change only when the GitHub App is regenerated. The $1.20/month savings matters on a student budget.

## Consequences

- Secrets stored at paths like `/shipzero/dev/github/webhook_secret`
- Created manually via CLI (`aws ssm put-parameter`), referenced in Terraform via `data` sources
- If we later need rotation, we'll add a Lambda-based rotation and optionally migrate to Secrets Manager
