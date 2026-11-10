output "name" {
  description = "Bucket name, built by the naming convention. Known at plan time."
  value       = local.bucket_name
}

output "id" {
  description = "Bucket name as created."
  value       = module.bucket.s3_bucket_id
}

output "arn" {
  description = "Bucket ARN, for IAM policies (`<arn>` for the bucket, `<arn>/*` for objects)."
  value       = module.bucket.s3_bucket_arn
}

output "bucket_regional_domain_name" {
  description = "Region-specific domain name, for CloudFront origins and VPC endpoints."
  value       = module.bucket.s3_bucket_bucket_regional_domain_name
}

output "region" {
  description = "Region the bucket lives in."
  value       = module.bucket.s3_bucket_region
}

output "tags" {
  description = "Tags this module sets on the bucket (Name, Region, ManagedBy and your `tags`). The provider adds its default_tags on top."
  value       = local.resource_tags
}
