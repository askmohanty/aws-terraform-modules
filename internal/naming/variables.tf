variable "org" {
  description = "Short organisation code, the first part of every name (e.g. `acme`)."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{1,11}$", var.org))
    error_message = "`org` is 2-12 lowercase letters and digits, starting with a letter."
  }
}

variable "environment" {
  description = "Environment, the second part of every name. Must be one of `allowed_environments`."
  type        = string

  validation {
    condition     = contains(var.allowed_environments, var.environment)
    error_message = "`environment` must be one of `allowed_environments`."
  }
}

variable "allowed_environments" {
  description = "Environments this organisation uses. Keep it in step with the OPA policy data (`policies/data/config.yaml`)."
  type        = list(string)
  default     = ["dev", "test", "staging", "prod"]
}

variable "region" {
  description = "AWS region the resources live in (e.g. `eu-west-1`). Shortened in names: `eu-west-1` becomes `euw1`."
  type        = string

  validation {
    condition     = can(regex("^[a-z]{2}(-[a-z]+)+-[0-9]+$", var.region))
    error_message = "`region` must be an AWS region code such as `eu-west-1`."
  }
}

variable "name" {
  description = "What the resource is for, the last part of the name (e.g. `orders-db`)."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,38}[a-z0-9]$", var.name))
    error_message = "`name` is 2-40 lowercase letters, digits and hyphens, starting with a letter and not ending with a hyphen."
  }
}

variable "owner" {
  description = "Team or person accountable for the resource, added as the `Owner` tag."
  type        = string
  default     = null
}

variable "cost_centre" {
  description = "Cost centre, added as the `CostCentre` tag."
  type        = string
  default     = null
}

variable "extra_tags" {
  description = "Additional tags. The standard tags (`Name`, `Org`, `Environment`, `Region`, `ManagedBy`, `Owner`, `CostCentre`) always win over these."
  type        = map(string)
  default     = {}
}
