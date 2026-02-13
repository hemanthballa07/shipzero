# Route53 — Phase 2
# Data source for existing hosted zone (do NOT create a new one).
#
# data "aws_route53_zone" "main" {
#   name = "${var.domain_name}."
# }
#
# DNS records will be added in Phase 13.
