# ShipZero — Build Contract

> **Owner**: Vivek · **Reviewer**: Hemanth
> This document defines the interface between the control plane and the build plane.

## Build Trigger

The control plane fires a `BuildRequested` EventBridge event with this payload:

```json
{
  "source": "shipzero",
  "detail-type": "BuildRequested",
  "detail": {
    "projectId": "proj_abc123",
    "deployId": "deploy_xyz789",
    "repoUrl": "https://github.com/user/repo",
    "branch": "main",
    "commitSha": "a1b2c3d4e5f6...",
    "buildCommand": "npm run build",
    "outputDir": "dist",
    "timestamp": "2026-02-12T00:00:00Z"
  }
}
```

## CodeBuild Environment Variables

Passed at `StartBuild` time by Step Functions:

| Variable          | Source                                  | Example |
|-------------------|-----------------------------------------|-------------------|
| `PROJECT_ID`      | Event detail                            | `proj_abc123` |
| `DEPLOY_ID`       | Event detail                            | `deploy_xyz789` |
| `REPO_URL`        | Event detail                            | `https://github.com/user/repo` |
| `BRANCH`          | Event detail                            | `main` |
| `COMMIT_SHA`      | Event detail                            | `a1b2c3d4...` |
| `BUILD_COMMAND`   | Event detail (default: `npm run build`) | `npm run build` |
| `OUTPUT_DIR`      | Event detail (default: `dist`)          | `dist` |
| `ARTIFACTS_BUCKET`| Terraform output                        | `shipzero-artifacts-dev` |
| `SITES_BUCKET`    | Terraform output                        | `shipzero-sites-dev` |

## Buildspec Phases

**File**: `buildspecs/default.yml`

| Phase | Action |
|---|---|
| `install` | Clone repo at `COMMIT_SHA`, run `npm ci` |
| `build` | Run `BUILD_COMMAND` |
| `post_build` | Upload to artifacts, promote to sites (two-step) |

### Post-Build Promotion (Atomic-ish)

```bash
# Step 1: Upload build output to artifacts bucket
aws s3 sync "$OUTPUT_DIR" "s3://$ARTIFACTS_BUCKET/builds/$PROJECT_ID/$COMMIT_SHA/"

# Step 2: Promote — sync everything EXCEPT index.html
aws s3 sync "$OUTPUT_DIR" "s3://$SITES_BUCKET/sites/$PROJECT_ID/latest/" \
  --exclude "index.html" --delete

# Step 3: Upload index.html LAST (switchover)
aws s3 cp "$OUTPUT_DIR/index.html" \
  "s3://$SITES_BUCKET/sites/$PROJECT_ID/latest/index.html" \
  --cache-control "no-cache"
```

**Why this order**: If `index.html` references hashed assets (`main.abc123.js`), uploading it before the assets causes broken pages. Assets first, then the HTML that references them.

## Build Output Contract

CodeBuild must exit with:
- **Exit code 0**: Build succeeded → Step Functions continues to `LIVE`
- **Non-zero exit code**: Build failed → Step Functions emits `BuildFailed`

## Artifact Layout

After a successful build:

```
s3://shipzero-artifacts-dev/builds/{projectId}/{commitSha}/
  ├── index.html
  ├── assets/
  │   ├── main.abc123.js
  │   └── style.def456.css
  └── ...

s3://shipzero-sites-dev/sites/{projectId}/latest/
  ├── (same structure, promoted from artifacts)
```

## Caching

- CodeBuild S3 cache: `s3://shipzero-artifacts-dev/cache/`
- Caches `node_modules` between builds
- Significantly reduces `npm ci` time for repeat builds

## Timeouts

| Component | Timeout |
|---|---|
| CodeBuild project | 10 minutes |
| Step Functions execution | 15 minutes |
| Build polling interval | 15 seconds |
