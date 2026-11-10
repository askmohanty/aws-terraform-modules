variable "context" {
  description = "Naming and tagging context shared by every module in a stack. See `modules/naming`."
  type = object({
    org                  = string
    environment          = string
    region               = string
    owner                = optional(string)
    cost_centre          = optional(string)
    extra_tags           = optional(map(string), {})
    allowed_environments = optional(list(string), ["dev", "test", "staging", "prod"])
  })
}

variable "name" {
  description = "What the bucket is for (e.g. `orders-data`). The bucket is named `{org}-{environment}-{region_short}-{name}[-{name_suffix}]`."
  type        = string
}

variable "name_suffix" {
  description = "Optional suffix appended to the bucket name, for global uniqueness (bucket names are unique across all AWS accounts). For example a short account ID or random string."
  type        = string
  default     = null

  validation {
    condition     = var.name_suffix == null ? true : can(regex("^[a-z0-9]{1,12}$", var.name_suffix))
    error_message = "`name_suffix` is 1-12 lowercase letters and digits."
  }
}

variable "force_destroy" {
  description = "Allow `terraform destroy` to delete a bucket that still contains objects. Refused in `prod`."
  type        = bool
  default     = false
}

variable "versioning_enabled" {
  description = "Keep previous versions of overwritten and deleted objects. Refused as false in `prod`."
  type        = bool
  default     = true
}

variable "kms_key_arn" {
  description = "Customer-managed KMS key for default encryption. When set, uploads that request a different key are denied. When null, the AWS-managed `aws/s3` key is used."
  type        = string
  default     = null

  validation {
    condition     = var.kms_key_arn == null ? true : can(regex("^arn:aws[a-z-]*:kms:[a-z0-9-]+:[0-9]{12}:key/.+$", var.kms_key_arn))
    error_message = "`kms_key_arn` must be a KMS key ARN (`arn:aws:kms:<region>:<account>:key/<id>`)."
  }
}

variable "noncurrent_version_expiration_days" {
  description = "Delete previous object versions this many days after they stop being current. Null keeps them forever."
  type        = number
  default     = 90

  validation {
    condition     = var.noncurrent_version_expiration_days == null ? true : var.noncurrent_version_expiration_days >= 1
    error_message = "`noncurrent_version_expiration_days` must be at least 1, or null."
  }
}

variable "lifecycle_rules" {
  description = "Extra lifecycle rules: expire or transition objects under a prefix."
  type = list(object({
    id              = string
    prefix          = optional(string, "")
    expiration_days = optional(number)
    transitions = optional(list(object({
      days          = number
      storage_class = string
    })), [])
  }))
  default = []

  validation {
    condition = alltrue(flatten([
      for r in var.lifecycle_rules : [
        for t in r.transitions : contains(["STANDARD_IA", "ONEZONE_IA", "INTELLIGENT_TIERING", "GLACIER_IR", "GLACIER", "DEEP_ARCHIVE"], t.storage_class)
      ]
    ]))
    error_message = "Transition storage classes must be one of STANDARD_IA, ONEZONE_IA, INTELLIGENT_TIERING, GLACIER_IR, GLACIER or DEEP_ARCHIVE."
  }
}

variable "access_logging" {
  description = "Write server access logs to another bucket. Null turns access logging off."
  type = object({
    target_bucket = string
    target_prefix = optional(string, "")
  })
  default = null
}

variable "policy_json" {
  description = "Extra bucket policy (JSON from `jsonencode` or `aws_iam_policy_document`), merged with the built-in deny statements (TLS, KMS key). Statements that allow access to everyone (`Principal: \"*\"`) are refused."
  type        = string
  default     = null

  validation {
    condition     = var.policy_json == null ? true : can(jsondecode(var.policy_json).Statement)
    error_message = "`policy_json` must be a policy document with a `Statement`."
  }

  validation {
    condition = var.policy_json == null ? true : alltrue([
      for s in flatten([try(jsondecode(var.policy_json).Statement, [])]) :
      !(try(s.Effect, "") == "Allow" && (
        try(s.Principal == "*", false) ||
        try(s.Principal.AWS == "*", false) ||
        try(contains(s.Principal.AWS, "*"), false)
      ))
    ])
    error_message = "The bucket policy must not allow access to everyone (`Principal: \"*\"`). Grant access to specific roles or accounts."
  }
}

variable "tags" {
  description = "Extra tags. The standard naming tags always win."
  type        = map(string)
  default     = {}
}
