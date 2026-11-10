# Naming a resource that no tier-1 module covers yet, so it still follows the convention.
terraform {
  required_version = ">= 1.9"
}

module "name" {
  source = "../.."

  org         = "acme"
  environment = "dev"
  region      = "eu-west-1"
  name        = "orders-queue"
  owner       = "orders-team"
}

output "name" {
  value = module.name.id # acme-dev-euw1-orders-queue
}

output "tags" {
  value = module.name.tags
}
