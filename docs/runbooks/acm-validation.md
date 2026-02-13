# Runbook: ACM Certificate Validation

> Complete this during Phase 3, after DNS delegation is confirmed.

## Prerequisites

- DNS delegation complete (`dig NS shipzero.space` returns Route53 NS)
- Terraform `modules/edge/acm.tf` implemented

## Steps

- [ ] Apply Terraform to create ACM certificate (DNS validation method)
- [ ] Terraform auto-creates Route53 CNAME validation records
- [ ] Wait for ACM status: `aws acm describe-certificate --certificate-arn <ARN> --query 'Certificate.Status'`
- [ ] Expected: `ISSUED` (can take 5–30 minutes)

## Verification

```bash
aws acm describe-certificate \
  --certificate-arn <ARN> \
  --query 'Certificate.{Status:Status,DomainName:DomainName,SANs:SubjectAlternativeNames}'
```

Expected output: Status=ISSUED, covering `shipzero.space` + `*.shipzero.space`

## Common Issues

| Symptom | Cause | Fix |
|---|---|---|
| Status stuck at `PENDING_VALIDATION` | DNS delegation incomplete | Complete DNS delegation first |
| Validation record not created | Terraform error | Check `terraform apply` output |
| Wrong region | Cert not in us-east-1 | Delete and recreate in us-east-1 |
