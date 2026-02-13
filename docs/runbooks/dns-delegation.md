# Runbook: DNS Delegation

> Complete this during Phase 2 when ready to point `shipzero.space` to Route53.

## Prerequisites

- Route53 hosted zone exists for `shipzero.space`
- Access to domain registrar dashboard

## Steps

- [ ] Get Route53 NS records: `aws route53 get-hosted-zone --id <ZONE_ID> --query 'DelegationSet.NameServers'`
- [ ] Log into registrar (note which one: ____________)
- [ ] Update custom nameservers to the four Route53 NS values
- [ ] Wait for propagation (24–48 hours)
- [ ] Verify: `dig NS shipzero.space +short` → should show Route53 NS records
- [ ] Verify: `dig NS shipzero.space @8.8.8.8 +short` → cross-check with Google DNS

## Rollback

If something breaks, revert nameservers to the registrar defaults at the registrar dashboard.

## Common Issues

| Symptom | Cause | Fix |
|---|---|---|
| `dig` still shows old NS | Propagation delay | Wait, retry after 1 hour |
| ACM validation stuck | NS not delegated yet | Complete delegation first |
| Partial delegation | Only updated some NS records | Ensure all 4 NS values are set |
