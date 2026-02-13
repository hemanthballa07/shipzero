# S3 artifacts bucket — Phase 4
# Private, SSE-AES256, 7-day lifecycle on builds/ prefix.
#
# Resources to create:
#   aws_s3_bucket.artifacts
#   aws_s3_bucket_server_side_encryption_configuration.artifacts
#   aws_s3_bucket_public_access_block.artifacts
#   aws_s3_bucket_lifecycle_configuration.artifacts
