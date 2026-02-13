# ADR-004: Two-Step S3 Promotion

**Status**: Accepted  
**Date**: 2026-02-12

## Context

When deploying a static site, if `index.html` is uploaded before its referenced assets (`main.abc123.js`, `style.def456.css`), users briefly see a broken page with 404'd assets.

## Decision

Use a **two-step promotion** inside CodeBuild's `post_build` phase:

1. `aws s3 sync` all files excluding `index.html` (with `--delete`)
2. `aws s3 cp index.html` as the last operation

## Why Not Blue-Green / Versioned Paths

- Blue-green with S3 prefix swapping adds CloudFront Function complexity (path rewriting)
- Versioned paths (`/v42/`) require build-time path injection and client-side config
- Two-step is simple, correct enough for SSG, and requires no extra infrastructure

## Consequences

- There is still a brief window (milliseconds) where assets are updated but `index.html` points to old asset hashes — this is acceptable for SSG
- If we need true atomic deploys later (SSR, critical paths), we'll revisit blue-green with S3 prefix swapping
- Promotion logic lives in the buildspec, not Step Functions — simpler IAM, fewer moving pieces
