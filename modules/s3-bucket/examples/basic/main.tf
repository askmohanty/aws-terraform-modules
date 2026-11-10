terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.44, < 7.0"
    }
  }
}

# Stack-wide facts are set once, on the provider. Every module reads them.
provider "aws" {
  region = "eu-west-1"

  default_tags {
    tags = {
      Org         = "acme"
      Environment = "dev"
      Owner       = "orders-team"
    }
  }
}

module "orders_data" {
  source = "../.."

  name        = "orders-data" # -> acme-dev-euw1-orders-data-ex1
  name_suffix = "ex1"         # bucket names are global; a suffix avoids collisions

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
