# ShipZero — Architecture (Locked v3)

## System Overview

ShipZero is a multi-tenant static hosting platform. Users connect a GitHub repo; every `git push` triggers an automated build and deploys the output to a globally-distributed CDN. Each project gets a subdomain (`{slug}.shipzero.space`) and optional preview URLs for branches.

## Planes

| Plane       | Responsibility                        | AWS Services                                        |
|-------------|---------------------------------------|-----------------------------------------------------|
| **Edge**    | Serve sites, TLS termination, routing | CloudFront, S3, Route53, ACM, CloudFront Functions  |
| **Control** | API, state management, event dispatch | API Gateway HTTP API, Lambda, DynamoDB, EventBridge |
| **Build**   | Clone → build → promote to S3         | Step Functions, CodeBuild, S3, SSM Parameter Store  |

## Request Flow

```
User pushes to GitHub
  │
  ▼
GitHub sends POST /webhooks/github (with HMAC signature)
  │
  ▼
API Gateway HTTP API → Lambda (webhook handler)
  ├── Verify X-Hub-Signature-256 (HMAC-SHA256 with webhook secret from SSM)
  ├── Extract projectId, commitSha, branch, repoUrl
  ├── Atomic idempotency check:
  │     PutItem PK="BUILD#PROJECT#{projectId}#COMMIT#{commitSha}"
  │     ConditionExpression: attribute_not_exists(PK)
  │     └── ConditionalCheckFailedException → return 200 (already building)
  ├── Create deployment record in DynamoDB (status=QUEUED)
  └── Emit BuildRequested event to EventBridge
         │
         ▼
EventBridge rule matches "BuildRequested"
  → Starts Step Functions execution
         │
         ▼
Step Functions state machine:
  1. UpdateDeployStatus("BUILDING")        → DynamoDB
  2. StartCodeBuild                        → CodeBuild
  3. WaitForBuild (poll every 15s)
     ├── SUCCEEDED → continue
     └── FAILED → EmitBuildFailed → END
  4. PromoteToSites (in CodeBuild post_build):
     ├── s3 sync (all except index.html)
     └── s3 cp index.html (last — atomic switchover)
  5. UpdateDeployStatus("LIVE")            → DynamoDB
  6. InvalidateCloudFrontCache             → CloudFront
  7. EmitDeployCompleted                   → EventBridge
         │
         ▼
Site live at https://{slug}.shipzero.space
  (CloudFront Function rewrites Host → S3 key path)
```

## DynamoDB Single-Table Schema

**Table**: `shipzero-table-{env}` — On-demand, PITR enabled

| Keys | Attribute | Type |
|---|---|---|
| Partition key | `PK` | String |
| Sort key | `SK` | String |
| GSI-1 partition | `GSI1PK` | String |
| GSI-1 sort | `GSI1SK` | String |

### Entity Key Patterns

| Entity | PK | SK | GSI1PK | GSI1SK |
|---|---|---|---|---|
| Project | `USER#{userId}` | `PROJECT#{projectId}` | `PROJECT#{projectId}` | `#METADATA` |
| Deployment | `PROJECT#{projectId}` | `DEPLOY#{ts}#{deployId}` | `DEPLOY#{deployId}` | `#METADATA` |
| EnvVar | `PROJECT#{projectId}` | `ENVVAR#{key}` | — | — |
| Domain | `PROJECT#{projectId}` | `DOMAIN#{fqdn}` | `DOMAIN#{fqdn}` | `#METADATA` |
| BuildDedupe | `BUILD#PROJECT#{id}#COMMIT#{sha}` | `METADATA` | — | — |
| BuildLog | `DEPLOY#{deployId}` | `LOG#{ts}` | — | — |

### Access Patterns

| # | Pattern | Key / Index |
|---|---|---|
| 1 | List user's projects | Base: `PK=USER#{userId}`, SK begins_with `PROJECT#` |
| 2 | Get project by ID | GSI1: `GSI1PK=PROJECT#{projectId}`, GSI1SK=`#METADATA` |
| 3 | List deployments | Base: `PK=PROJECT#{projectId}`, SK begins_with `DEPLOY#` |
| 4 | Get deployment | GSI1: `GSI1PK=DEPLOY#{deployId}` |
| 5 | Domain lookup | GSI1: `GSI1PK=DOMAIN#{fqdn}` |
| 6 | Build dedupe check | Base: `PK=BUILD#PROJECT#{id}#COMMIT#{sha}` |

## S3 Bucket Layout

**Artifacts** (`shipzero-artifacts-dev`):
```
builds/{projectId}/{commitSha}/    ← raw build output (7-day lifecycle)
cache/                             ← CodeBuild node_modules cache
```

**Sites** (`shipzero-sites-dev`):
```
sites/{slug}/latest/               ← production deployment
sites/{slug}/preview/{branchSlug}/ ← preview deployment
sites/_root/latest/                ← apex domain landing page
```

## CloudFront Function Routing

The viewer-request function parses the `Host` header and rewrites the URI:

| Request Host | Rewritten URI |
|---|---|
| `myapp.shipzero.space` | `/sites/myapp/latest/{path}` |
| `feat-login.myapp.shipzero.space` | `/sites/myapp/preview/feat-login/{path}` |
| `shipzero.space` | `/sites/_root/latest/{path}` |
| `www.shipzero.space` | `/sites/_root/latest/{path}` |

**Constraints**: No network calls, ES 5.1 only, 1ms execution budget, 2MB memory.

## DNS Records

| Record | Type | Target |
|---|---|---|
| `shipzero.space` | A + AAAA (Alias) | CloudFront distribution |
| `www.shipzero.space` | A (Alias) | CloudFront distribution |
| `*.shipzero.space` | A + AAAA (Alias) | CloudFront distribution |

Alias hosted zone ID for CloudFront: **`Z2FDTNDATAQYW2`** (constant for all distributions).

## Invariants

These must always hold:

1. **Idempotency**: Same `(projectId, commitSha)` triggers at most one build
2. **Atomic promotion**: `index.html` is always the last file uploaded
3. **No public S3**: Both buckets block all public access; sites served via OAC only
4. **No VPC**: CodeBuild runs non-VPC — no NAT Gateway cost
5. **On-demand only**: DynamoDB never uses provisioned capacity
6. **Secrets in SSM only**: Never in env vars, code, or Terraform outputs
