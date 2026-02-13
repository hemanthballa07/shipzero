# ShipZero — Developer Workflow

## Git Branching

| Branch | Purpose | Merge Strategy |
|---|---|---|
| `main` | Deployable trunk | PR only, squash merge |
| `infra/{phase}-{desc}` | Terraform changes | Reviewed by both |
| `build/{feature}` | Lambda / buildspec changes | Reviewed by both |
| `docs/{topic}` | Documentation only | Fast-track review OK |

### Branch Lifecycle

1. `git checkout main && git pull`
2. `git checkout -b infra/phase-2-route53`
3. Make changes, commit with descriptive messages
4. `git push -u origin infra/phase-2-route53`
5. Open PR on GitHub — add `terraform plan` output if infra
6. Get review from teammate → squash merge → delete branch

### Pull Strategy

```bash
# Already set globally:
git config --global pull.ff only
```

If you see "divergent branches", run `git fetch origin && git rebase origin/main`.

---

## Terraform Safety Protocol

### The Five Rules

1. **Never `terraform apply` without reading the plan first**
2. **Never modify AWS resources via console** that Terraform manages
3. **Always back up state** after successful apply
4. **Always commit `.terraform.lock.hcl`** — never commit `.terraform/` or `*.tfstate`
5. **Never put secrets in `.tf` files** — use SSM data sources

### Step-by-Step Apply

```bash
cd infra/envs/dev

# 1. Init (first time or after module changes)
terraform init

# 2. Format check
terraform fmt -check -recursive

# 3. Validate
terraform validate

# 4. Plan (ALWAYS review output)
terraform plan -var-file=dev.tfvars -out=plan.out

# 5. Apply (only after reviewing plan)
terraform apply plan.out

# 6. Back up state immediately
cp terraform.tfstate ~/shipzero-state-backups/terraform.tfstate.$(date +%Y%m%d%H%M)
```

### State Recovery

If state is lost or corrupt:

1. Check `~/shipzero-state-backups/` for latest backup
2. Copy it back: `cp ~/shipzero-state-backups/<latest> terraform.tfstate`
3. Run `terraform plan` to verify state matches reality
4. If no backup exists: `terraform import` each resource manually

### What Goes in PRs (Terraform)

Every Terraform PR description must include:

- [ ] Summary of what changes
- [ ] Full `terraform plan` output (copy-paste)
- [ ] Confirmation: `terraform validate` passes
- [ ] Cost impact note (if adding new resources)

---

## Ownership Matrix

| File / Directory | Owner | Reviewer |
|---|---|---|
| `infra/modules/edge/` | Hemanth | Vivek |
| `infra/modules/control/` | Hemanth | Vivek |
| `infra/modules/build/` | Hemanth | Vivek |
| `infra/envs/dev/` | Hemanth | Vivek |
| `lambdas/` | Vivek | Hemanth |
| `buildspecs/` | Vivek | Hemanth |
| `cf-functions/` | Vivek | Hemanth |
| `docs/` | Both | Both |
| `scripts/` | Both | Both |
| `README.md` | Both | Both |

**Rule**: No self-merging. Every PR gets at least one review.

---

## Environment Variables Reference

| Variable | Where Set | Value |
|---|---|---|
| `AWS_PROFILE` | Shell (`~/.zshrc`) | `shipzero-dev` |
| `TABLE_NAME` | Lambda env var | `shipzero-table-dev` |
| `EVENT_BUS_NAME` | Lambda env var | `default` |
| `STAGE` | Lambda env var | `dev` |
| `SSM_PREFIX` | Lambda env var | `/shipzero/dev` |
| `SITES_BUCKET` | CodeBuild env var | `shipzero-sites-dev` |
| `ARTIFACTS_BUCKET` | CodeBuild env var | `shipzero-artifacts-dev` |
