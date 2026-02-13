# ShipZero

> A Vercel-style serverless deployment platform built on AWS — push code, get a live URL.

ShipZero is a multi-tenant static site deployment platform that transforms `git push` into live, globally-distributed websites. It provides automatic builds, instant preview deployments for every branch, wildcard SSL, and CDN-backed delivery — all running on serverless AWS infrastructure at student-budget cost (<$3/month for dev).

**Status**: 🟡 In Development — Phase 0 complete (scaffold), executing Phase 1–3

---

## Architecture (Locked v3)

Three isolated planes, each independently deployable:

```
┌─────────────────────────────────────────────────────────────────┐
│                        EDGE PLANE                               │
│  CloudFront (PriceClass_100) + CF Function (viewer-request)     │
│  S3 sites bucket (OAC) │ Route53 wildcard │ ACM wildcard cert   │
└──────────────────────────────┬──────────────────────────────────┘
                               │ serves static assets
┌──────────────────────────────┴──────────────────────────────────┐
│                      CONTROL PLANE                              │
│  API Gateway HTTP API → Lambda (Node.js 20)                     │
│  DynamoDB (single-table, on-demand) │ EventBridge (default bus) │
└──────────────────────────────┬──────────────────────────────────┘
                               │ emits BuildRequested
┌──────────────────────────────┴──────────────────────────────────┐
│                       BUILD PLANE                               │
│  Step Functions (Standard) → CodeBuild (non-VPC, SMALL)         │
│  S3 artifacts bucket (7-day lifecycle) │ SSM Parameter Store    │
└─────────────────────────────────────────────────────────────────┘
```

**Request flow**: `git push` → GitHub webhook → API Gateway → Lambda (HMAC verify + idempotency check) → EventBridge → Step Functions → CodeBuild (build) → S3 sync (assets first, `index.html` last) → CloudFront invalidation → live at `{project}.shipzero.space`

Key design decisions:
- **SSM Parameter Store** over Secrets Manager (free vs $0.40/secret/month) — [ADR-001](docs/adr/001-ssm-over-secrets-manager.md)
- **Single-table DynamoDB** with GSI for all entity access patterns — [ADR-002](docs/adr/002-single-table-dynamodb.md)
- **CloudFront Function** (not Lambda@Edge) for host-based routing — stateless, 1ms budget, no DB lookups
- **Atomic idempotency** via `PutItem` + `attribute_not_exists(PK)` — no "check-then-write" races
- **Two-step S3 promotion** — sync assets first, upload `index.html` last — prevents broken-page flashes

---

## Tech Stack

| Layer | Technology | Version / Tier |
|---|---|---|
| IaC | Terraform | >= 1.5, AWS provider ~> 5.x |
| Compute | AWS Lambda | Node.js 20.x |
| API | API Gateway | HTTP API (not REST) |
| Database | DynamoDB | On-demand, single-table |
| Events | EventBridge | Default bus |
| Orchestration | Step Functions | Standard |
| Build | CodeBuild | `standard:7.0`, `BUILD_GENERAL1_SMALL` |
| CDN | CloudFront | PriceClass_100, OAC |
| Edge Logic | CloudFront Functions | Viewer-request |
| Storage | S3 | SSE-AES256, lifecycle rules |
| DNS | Route53 | Public hosted zone |
| SSL | ACM | Wildcard, us-east-1 |
| Secrets | SSM Parameter Store | Standard tier (free) |
| Source Control | GitHub | App + webhooks |
| Region | AWS | us-east-1 |

---

## Repo Structure

```
shipzero/
├── infra/                          # All Terraform code
│   ├── envs/dev/                   # Root module for dev environment
│   │   ├── providers.tf            # AWS provider + default tags
│   │   ├── backend.tf              # Local state backend
│   │   ├── main.tf                 # Module composition
│   │   ├── variables.tf            # Input variables
│   │   ├── outputs.tf              # Surfaced values
│   │   └── dev.tfvars              # Dev-specific values
│   └── modules/
│       ├── edge/                   # CloudFront, Route53, ACM, S3-sites
│       ├── control/                # API GW, Lambda, DynamoDB, EventBridge
│       └── build/                  # CodeBuild, Step Functions, S3-artifacts, SSM
├── lambdas/                        # Lambda source code (Node.js 20)
│   ├── api/                        # Control plane handlers
│   └── shared/                     # Shared utilities (logger, DynamoDB client)
├── cf-functions/                   # CloudFront Function JS (ES 5.1)
├── buildspecs/                     # CodeBuild buildspec YAML files
├── scripts/                        # Helper scripts (webhook signing, testing)
├── docs/                           # Architecture docs, ADRs, runbooks
│   ├── ARCHITECTURE.md             # Full system design
│   ├── WORKFLOW.md                 # Terraform safety + git branching rules
│   ├── BUILD.md                    # Build contract (Vivek's domain)
│   ├── adr/                        # Architecture Decision Records
│   └── runbooks/                   # Operational runbooks
└── .github/                        # GitHub App config docs
```

**Plane → Module mapping**: Each module maps to exactly one plane. Cross-plane references flow through Terraform outputs, never hardcoded ARNs.

---

## Team Workflow

### Ownership Split

| Area | Owner | Scope |
|---|---|---|
| Infrastructure (Terraform) | **Hemanth** | All `infra/`, Route53, ACM, CloudFront, IAM, DynamoDB table |
| Build contract + app logic | **Vivek** | `lambdas/`, `buildspecs/`, `cf-functions/`, CodeBuild logic |
| Shared | Both | `docs/`, `scripts/`, `README.md`, PR reviews |

### Git Flow

- **`main`** — protected, always deployable, PR-only
- **Feature branches** — `{area}/{description}` (e.g., `infra/phase-2-route53`, `build/webhook-handler`)
- **PR rules**:
  - Every PR needs at least one review from the other person
  - Terraform PRs must include `terraform plan` output in the PR description
  - Squash merge preferred — keeps `main` history clean
- **Pull strategy** — `pull.ff only` (set globally, prevents merge noise)

### Terraform Safety Protocol

1. Always `terraform plan -var-file=dev.tfvars -out=plan.out` before apply
2. Review the plan — never auto-approve
3. After successful apply: back up state to `~/shipzero-state-backups/`
4. Never modify AWS console resources that Terraform manages
5. Commit `.terraform.lock.hcl` — do not commit `.terraform/` or `*.tfstate`

See [docs/WORKFLOW.md](docs/WORKFLOW.md) for the full protocol.

---

## Cost Guardrails

> **Budget**: ~$200 student credits. Target dev cost: **<$3/month**.

### What's Free

| Service | Why Free |
|---|---|
| Lambda | 1M requests + 400K GB-seconds/month free |
| API Gateway HTTP API | First 12 months free tier |
| CloudFront | 1 TB transfer + 10M requests/month |
| CodeBuild | 100 build-minutes/month |
| SSM Parameter Store | Standard tier is free |
| ACM | Public certs are free |
| IAM | Always free |

### What Costs Money

| Service | Cost | Control |
|---|---|---|
| Route53 hosted zone | $0.50/month (fixed) | None needed — one zone only |
| DynamoDB | ~$0.25/month at dev traffic | On-demand billing, no provisioned capacity |
| S3 | ~$0.10/month at <1 GB | 7-day lifecycle on `builds/` prefix |
| CloudWatch | ~$1.00/month | 14-day log retention, limit alarms |

### Cost Alarm Rules

- [ ] Set a **Billing Alarm** at $5/month and $20/month in CloudWatch
- [ ] **Never** use NAT Gateway, VPC for CodeBuild, or Lambda@Edge
- [ ] **Never** use DynamoDB provisioned capacity
- [ ] **Never** use REST API (always HTTP API)
- [ ] Monitor CodeBuild minutes — biggest variable cost risk ($0.005/min after free tier)
- [ ] Review `AWS Cost Explorer` weekly during active development

### Monthly Cost Estimate (Dev)

| Line item | Estimate |
|---|---|
| Route53 | $0.50 |
| DynamoDB | $0.25 |
| S3 | $0.10 |
| CloudWatch | $1.00 |
| Everything else | Free tier |
| **Total** | **~$2–3/month** |

---

## Current Status

| Phase | Description | Status |
|---|---|---|
| 0 | Project conventions + scaffold | ✅ Complete |
| 1 | AWS account hardening + IAM | ⬜ Not started |
| 2 | Route53 hosted zone validation | ⬜ Not started |
| 3 | ACM wildcard certificate | ⬜ Not started |
| 4–5 | S3 buckets + DynamoDB | ⬜ Not started |
| 6–8 | GitHub App + Control plane | ⬜ Not started |
| 9–10 | Step Functions + CodeBuild | ⬜ Not started |
| 11–13 | CloudFront + DNS records | ⬜ Not started |
| 14 | Preview deployments | ⬜ Not started |
| 15–17 | Observability + security | ⬜ Not started |

**Next milestone**: Phase 1–3 (IAM, DNS delegation, ACM cert) — target: Week 1

---

## Local Development

### Prerequisites

- AWS CLI v2 with `shipzero-dev` profile configured
- Terraform >= 1.5
- Node.js 20
- Git with `pull.ff only` set

### Quick Start

```bash
git clone https://github.com/hemanthballa07/shipzero.git
cd shipzero/infra/envs/dev
terraform init
terraform plan -var-file=dev.tfvars
```

### Useful Commands

| Action | Command |
|---|---|
| Plan | `terraform plan -var-file=dev.tfvars -out=plan.out` |
| Apply | `terraform apply plan.out` |
| Backup state | `cp terraform.tfstate ~/shipzero-state-backups/terraform.tfstate.$(date +%Y%m%d%H%M)` |
| Validate | `terraform validate` |
| Format | `terraform fmt -recursive` |

---

## Documentation Index

| Document | Purpose |
|---|---|
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | Full system design, data flows, DynamoDB schema |
| [WORKFLOW.md](docs/WORKFLOW.md) | Terraform safety, branching, PR protocol |
| [BUILD.md](docs/BUILD.md) | Build contract: buildspec, env vars, artifact layout |
| [ADR Index](docs/adr/README.md) | Architecture Decision Records |
| [Runbooks](docs/runbooks/) | Operational procedures (DNS, ACM, CloudFront, webhooks) |

---

## License

Proprietary — see [LICENSE](LICENSE).
