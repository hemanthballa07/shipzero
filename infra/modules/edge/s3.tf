# S3 — Phase 4 (sites bucket)
# Private bucket, OAC-only access, SSE-AES256.
# Bucket policy added in Phase 11 after CloudFront is created.
#
# Resources to create:
#   aws_s3_bucket.sites
#   aws_s3_bucket_server_side_encryption_configuration.sites
#   aws_s3_bucket_public_access_block.sites
