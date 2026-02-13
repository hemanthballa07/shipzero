# Outputs populated as resources are created in later phases.
# Uncomment when resources exist:

# output "cloudfront_distribution_domain" {
#   description = "CloudFront distribution domain name"
#   value       = aws_cloudfront_distribution.main.domain_name
# }

# output "cloudfront_distribution_id" {
#   description = "CloudFront distribution ID"
#   value       = aws_cloudfront_distribution.main.id
# }

# output "hosted_zone_id" {
#   description = "Route53 hosted zone ID"
#   value       = data.aws_route53_zone.main.zone_id
# }

# output "acm_certificate_arn" {
#   description = "ACM wildcard certificate ARN"
#   value       = aws_acm_certificate.wildcard.arn
# }

# output "sites_bucket_name" {
#   description = "S3 sites bucket name"
#   value       = aws_s3_bucket.sites.id
# }
