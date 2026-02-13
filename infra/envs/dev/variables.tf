variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project" {
  description = "Project name used in resource naming"
  type        = string
  default     = "shipzero"
}

variable "domain_name" {
  description = "Root domain name for the platform"
  type        = string
}
