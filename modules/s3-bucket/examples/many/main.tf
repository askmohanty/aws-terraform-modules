# Many buckets from one map: the usual tier-2 pattern. Each key is the bucket's purpose (its `name`);
# every bucket still gets the naming convention, guardrails and policies.
terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.44, < 7.0"
    }
  }
}

variable "environment" {
  description = "Plugged in per environment (environments/<env>.tfvars or TF_VAR_environment)."
  type        = string
  default     = "dev"
}

variable "region" {
  type    = string
  default = "eu-west-1"
}

variable "buckets" {
  description = "Buckets to create, keyed by purpose."
  type = map(object({
    versioning_enabled = optional(bool, true)
    lifecycle_rules = optional(list(object({
      id              = string
      prefix          = optional(string, "")
      expiration_days = optional(number)
      transitions = optional(list(object({
        days          = number
        storage_class = string
      })), [])
    })), [])
  }))
  default = {
    orders-data = {}
    exports = {
      lifecycle_rules = [{ id = "expire", expiration_days = 30 }]
    }
    audit-logs = {
      lifecycle_rules = [{ id = "archive", transitions = [{ days = 90, storage_class = "GLACIER_IR" }] }]
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Org         = "acme"
      Environment = var.environment
      Owner       = "orders-team"
    }
  }
}

module "bucket" {
  source   = "../.."
  for_each = var.buckets

  name               = each.key
  name_suffix        = "ex1"
  versioning_enabled = each.value.versioning_enabled
  lifecycle_rules    = each.value.lifecycle_rules
}

output "bucket_names" {
  value = { for k, b in module.bucket : k => b.name }
}

output "bucket_arns" {
  value = { for k, b in module.bucket : k => b.arn }
}
