# Runbook: Webhook Testing

> Use this after Phase 7 to verify the GitHub webhook pipeline works end-to-end.

## Prerequisites

- API Gateway deployed with webhook endpoint
- Lambda function with HMAC verification
- GitHub App installed on a test repo
- Webhook secret stored in SSM at `/shipzero/dev/github/webhook_secret`

## Manual Webhook Test (Without GitHub)

Generate a test payload and HMAC signature locally:

```bash
# 1. Get the webhook secret
SECRET=$(aws ssm get-parameter --name "/shipzero/dev/github/webhook_secret" --with-decryption --query 'Parameter.Value' --output text)

# 2. Create a test payload
PAYLOAD='{"ref":"refs/heads/main","repository":{"full_name":"user/test-repo"},"head_commit":{"id":"abc123"}}'

# 3. Generate HMAC signature
SIG=$(echo -n "$PAYLOAD" | openssl dgst -sha256 -hmac "$SECRET" | cut -d' ' -f2)

# 4. Send request
curl -X POST https://<API_ENDPOINT>/webhooks/github \
  -H "Content-Type: application/json" \
  -H "X-Hub-Signature-256: sha256=$SIG" \
  -H "X-GitHub-Event: push" \
  -d "$PAYLOAD"
```

## Verification Checklist

- [ ] Lambda receives the request (check CloudWatch Logs)
- [ ] HMAC signature validates
- [ ] DynamoDB creates the build dedup record
- [ ] EventBridge receives `BuildRequested` event
- [ ] Second identical request returns 200 but does NOT create a duplicate

## Idempotency Test

- [ ] Send the same payload twice
- [ ] First request: should create dedup record + emit event
- [ ] Second request: should return 200 + log "duplicate, skipping"
- [ ] DynamoDB should have exactly one record for this `(projectId, commitSha)`

## Common Issues

| Symptom | Cause | Fix |
|---|---|---|
| 401/403 from API GW | Missing or wrong signature | Verify HMAC computation matches |
| Lambda timeout | DynamoDB or EventBridge issue | Check IAM policies |
| Duplicate builds | Idempotency not implemented | Verify `attribute_not_exists(PK)` condition |
