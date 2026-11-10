# Names for several resources at once, with the environment plugged in per environment.
terraform {
  required_version = ">= 1.9"
}

variable "environment" {
  description = "Environment, plugged in per environment (dev, test, staging or prod)."
  type        = string
  default     = "dev"
}

module "name" {
  source   = "../../modules/naming"
  for_each = toset(["orders-queue", "orders-dlq", "orders-topic"])

  org         = "acme"
  environment = var.environment
  region      = "eu-west-1"
  name        = each.key
}

output "names" {
  description = "Conventional name per resource."
  value       = { for k, n in module.name : k => n.id }
}
