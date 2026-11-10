# Helpers shared by every rule. Input is the JSON of a Terraform plan: `terraform show -json tfplan`.
package lib.plan

import rego.v1

# Resources the plan creates or updates (deletes and no-ops are not checked).
changes contains rc if {
	some rc in input.resource_changes
	some action in rc.change.actions
	action in {"create", "update"}
}

by_type(t) := {rc | some rc in changes; rc.type == t}

# Planned attributes. Values only known after apply are absent.
after(rc) := object.get(rc.change, "after", {})

# Module path of a resource ("" for the root module).
module_of(rc) := object.get(rc, "module_address", "")

# Organisation settings from policies/data/config.yaml, with defaults so rules work without it.
environments := data.naming.environments if {
	data.naming.environments
} else := ["dev", "test", "staging", "prod"]

org_pattern := data.naming.org_pattern if {
	data.naming.org_pattern
} else := "[a-z][a-z0-9]{1,11}"

required_tags := data.required_tags if {
	data.required_tags
} else := ["Name", "Org", "Environment", "ManagedBy"]

# An exception applies to one rule on one resource address until it expires.
excepted(rule, address) if {
	some e in data.exceptions
	e.rule == rule
	e.address == address
	time.now_ns() < time.parse_rfc3339_ns(e.expires)
}

is_prod(rc) if after(rc).tags.Environment == "prod"
