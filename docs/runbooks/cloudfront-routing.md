# Runbook: CloudFront Routing Verification

> Use this after Phase 11–12 to verify CloudFront serves sites correctly.

## Prerequisites

- CloudFront distribution deployed with OAC
- CloudFront Function associated (viewer-request)
- A test site uploaded to `s3://shipzero-sites-dev/sites/{slug}/latest/index.html`

## Steps

- [ ] Upload a test `index.html` to S3: `echo "<h1>Hello ShipZero</h1>" | aws s3 cp - s3://shipzero-sites-dev/sites/test-project/latest/index.html`
- [ ] Hit CloudFront directly: `curl -H "Host: test-project.shipzero.space" https://<DISTRIBUTION>.cloudfront.net/`
- [ ] Verify response is `<h1>Hello ShipZero</h1>`
- [ ] After DNS: `curl https://test-project.shipzero.space/`
- [ ] Check CloudFront Function logs (if enabled): CloudWatch → `/aws/cloudfront/function/shipzero-router-dev`

## SPA Fallback Test

- [ ] Request a non-root path: `curl https://test-project.shipzero.space/about`
- [ ] Should return `index.html` (SPA fallback), not 403/404

## Common Issues

| Symptom | Cause | Fix |
|---|---|---|
| 403 Forbidden | OAC misconfigured or bucket policy missing | Verify `aws_cloudfront_origin_access_control` and S3 bucket policy |
| 404 Not Found | CF Function routing error | Check function code, verify S3 key path |
| Old content | CloudFront cache | Invalidate: `aws cloudfront create-invalidation --distribution-id <ID> --paths "/*"` |
