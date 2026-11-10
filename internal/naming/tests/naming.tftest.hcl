variables {
  org         = "acme"
  environment = "prod"
  region      = "eu-west-1"
  name        = "orders-db"
}

run "builds_the_name" {
  command = plan

  assert {
    condition     = output.id == "acme-prod-euw1-orders-db"
    error_message = "Name must be {org}-{env}-{region_short}-{name}."
  }
}

run "shortens_regions" {
  command = plan

  variables {
    region = "ap-southeast-2"
  }

  assert {
    condition     = output.region_short == "apse2"
    error_message = "ap-southeast-2 must shorten to apse2."
  }
}

run "shortens_gov_regions" {
  command = plan

  variables {
    region = "us-gov-west-1"
  }

  assert {
    condition     = output.region_short == "usgw1"
    error_message = "us-gov-west-1 must shorten to usgw1."
  }
}

run "standard_tags_win_over_extra_tags" {
  command = plan

  variables {
    owner      = "payments-team"
    extra_tags = { Name = "spoofed", ManagedBy = "hand", Project = "orders" }
  }

  assert {
    condition = (
      output.tags.Name == "acme-prod-euw1-orders-db" &&
      output.tags.ManagedBy == "terraform" &&
      output.tags.Owner == "payments-team" &&
      output.tags.Project == "orders"
    )
    error_message = "Standard tags must override extra_tags; extra tags must be kept."
  }
}

run "omits_unset_optional_tags" {
  command = plan

  assert {
    condition     = !contains(keys(output.tags), "Owner") && !contains(keys(output.tags), "CostCentre")
    error_message = "Owner and CostCentre must only appear when set."
  }
}

run "rejects_unknown_environment" {
  command = plan

  variables {
    environment = "qa"
  }

  expect_failures = [var.environment]
}

run "rejects_bad_org" {
  command = plan

  variables {
    org = "ACME"
  }

  expect_failures = [var.org]
}

run "rejects_bad_name" {
  command = plan

  variables {
    name = "Orders_DB"
  }

  expect_failures = [var.name]
}

run "rejects_bad_region" {
  command = plan

  variables {
    region = "europe"
  }

  expect_failures = [var.region]
}
