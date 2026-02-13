# Build module — CodeBuild, Step Functions, S3-artifacts, SSM
# Activated in Phase 9–10.

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project" {
  description = "Project name"
  type        = string
}
