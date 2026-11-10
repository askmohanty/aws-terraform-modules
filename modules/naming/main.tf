locals {
  # eu-west-1 -> euw1, ap-southeast-2 -> apse2, us-gov-west-1 -> usgw1
  region_words = {
    north     = "n"
    south     = "s"
    east      = "e"
    west      = "w"
    central   = "c"
    northeast = "ne"
    northwest = "nw"
    southeast = "se"
    southwest = "sw"
    gov       = "g"
    iso       = "i"
    isob      = "ib"
  }
  region_parts = split("-", var.region)
  region_short = join("", concat(
    [local.region_parts[0]],
    [for p in slice(local.region_parts, 1, length(local.region_parts) - 1) : lookup(local.region_words, p, substr(p, 0, 1))],
    [local.region_parts[length(local.region_parts) - 1]],
  ))

  id = join("-", [var.org, var.environment, local.region_short, var.name])

  standard_tags = merge(
    {
      Name        = local.id
      Org         = var.org
      Environment = var.environment
      Region      = var.region
      ManagedBy   = "terraform"
    },
    var.owner == null ? {} : { Owner = var.owner },
    var.cost_centre == null ? {} : { CostCentre = var.cost_centre },
  )
}
