# Local backend for Phase 1.
# IMPORTANT: Back up terraform.tfstate after every successful apply:
#   cp terraform.tfstate ~/shipzero-state-backups/terraform.tfstate.$(date +%Y%m%d%H%M)
#
# Migrate to S3 + DynamoDB locking when ready for team use.
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
