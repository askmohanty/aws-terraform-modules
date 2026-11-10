output "id" {
  description = "Full resource name: `{org}-{environment}-{region_short}-{name}`, e.g. `acme-prod-euw1-orders-db`."
  value       = local.id
}

output "region_short" {
  description = "Short region code used in names, e.g. `euw1`."
  value       = local.region_short
}

output "tags" {
  description = "Tags every resource gets: `extra_tags` overlaid by the standard tags."
  value       = merge(var.extra_tags, local.standard_tags)
}
