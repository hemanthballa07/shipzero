# -----------------------------------------------------
# Root module — wires together edge, control, and build
# -----------------------------------------------------

module "edge" {
  source = "../../modules/edge"

  environment = var.environment
  project     = var.project
  domain_name = var.domain_name
}

# Uncomment when ready for Phase 5–8:
# module "control" {
#   source = "../../modules/control"
#
#   environment = var.environment
#   project     = var.project
# }

# Uncomment when ready for Phase 9–10:
# module "build" {
#   source = "../../modules/build"
#
#   environment = var.environment
#   project     = var.project
# }
