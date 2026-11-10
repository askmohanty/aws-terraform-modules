# Naming a resource that no tier-1 module covers yet, so it still follows the convention.
terraform {
  required_version = ">= 1.9"
}

module "name" {
  source = "../../modules/naming"

  org         = "acme"
  environment = "dev"
  region      = "eu-west-1"
  name        = "orders-queue"
  owner       = "orders-team"
}

output "name" {
  description = "The conventional name for your resource."
  value       = module.name.id # acme-dev-euw1-orders-queue
}

output "tags" {
  description = "Standard tags to put on your resource."
  value       = module.name.tags
}
