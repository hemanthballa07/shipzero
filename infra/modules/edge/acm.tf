# ACM — Phase 3
# Wildcard certificate for ${var.domain_name} + *.${var.domain_name}
# Must be in us-east-1 for CloudFront.
#
# Resources to create:
#   aws_acm_certificate.wildcard
#   aws_route53_record.cert_validation
#   aws_acm_certificate_validation.wildcard
