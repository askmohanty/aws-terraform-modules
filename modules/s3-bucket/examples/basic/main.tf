terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.44, < 7.0"
    }
  }
}

provider "aws" {
  region = "eu-west-1"
}

module "orders_data" {
  source = "../.."

  context = {
    org         = "acme"
    environment = "dev"
    region      = "eu-west-1"
    owner       = "orders-team"
  }

  name        = "orders-data"
  name_suffix = "ex1" # bucket names are global; a suffix avoids collisions

  lifecycle_rules = [{
    id          = "archive-exports"
    prefix      = "exports/"
    transitions = [{ days = 30, storage_class = "STANDARD_IA" }]
  }]
}

output "bucket_name" {
  value = module.orders_data.name
}

output "bucket_arn" {
  value = module.orders_data.arn
}
