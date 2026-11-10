# No arbitrary code execution from Terraform: provisioners and the `external` data source run
# commands on the machine running Terraform (OWASP A05 Injection, Agentic ASI05 Unexpected Code
# Execution). Reads the configuration section of the plan JSON.
package common.execution

import data.lib.plan
import rego.v1

# Every resource and data block in the root module and all module calls, at any depth.
config_resources contains r if {
	walk(input.configuration, [path, node])
	path[count(path) - 1] == "resources"
	some r in node
}

deny contains msg if {
	some r in config_resources
	some p in object.get(r, "provisioners", [])
	p.type in {"local-exec", "remote-exec"}
	not plan.excepted("no-exec-provisioners", r.address)
	msg := sprintf("[no-exec-provisioners] %s: %s provisioners are not allowed; use a resource or a module instead", [r.address, p.type])
}

deny contains msg if {
	some r in config_resources
	r.mode == "data"
	r.type == "external"
	not plan.excepted("no-external-data", r.address)
	msg := sprintf("[no-external-data] %s: the external data source runs a program during plan and is not allowed", [r.address])
}
