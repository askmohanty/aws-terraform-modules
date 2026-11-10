# Network: nothing reachable from the whole internet on admin ports or on every port.
package aws.network

import data.lib.plan
import rego.v1

world := {"0.0.0.0/0", "::/0"}

admin_ports := {22, 3389}

open_to_world(cidrs) if {
	some c in cidrs
	c in world
}

risky_range(protocol, _, _) if protocol in {"-1", "all"}

risky_range(_, from, to) if {
	from <= 0
	to >= 65535
}

risky_range(_, from, to) if {
	some p in admin_ports
	from <= p
	p <= to
}

# Inline ingress blocks on aws_security_group.
deny contains msg if {
	some sg in plan.by_type("aws_security_group")
	some rule in object.get(plan.after(sg), "ingress", [])
	open_to_world(array.concat(object.get(rule, "cidr_blocks", []), object.get(rule, "ipv6_cidr_blocks", [])))
	risky_range(rule.protocol, rule.from_port, rule.to_port)
	not plan.excepted("sg-world-ingress", sg.address)
	msg := sprintf("[sg-world-ingress] %s: ingress from the internet on ports %d-%d (%s) is not allowed", [sg.address, rule.from_port, rule.to_port, rule.protocol])
}

# Standalone rules: aws_vpc_security_group_ingress_rule.
deny contains msg if {
	some r in plan.by_type("aws_vpc_security_group_ingress_rule")
	a := plan.after(r)
	open_to_world([object.get(a, "cidr_ipv4", ""), object.get(a, "cidr_ipv6", "")])
	risky_range(a.ip_protocol, object.get(a, "from_port", 0), object.get(a, "to_port", 65535))
	not plan.excepted("sg-world-ingress", r.address)
	msg := sprintf("[sg-world-ingress] %s: ingress from the internet on admin or all ports is not allowed", [r.address])
}

# Legacy aws_security_group_rule.
deny contains msg if {
	some r in plan.by_type("aws_security_group_rule")
	a := plan.after(r)
	a.type == "ingress"
	open_to_world(array.concat(object.get(a, "cidr_blocks", []), object.get(a, "ipv6_cidr_blocks", [])))
	risky_range(a.protocol, a.from_port, a.to_port)
	not plan.excepted("sg-world-ingress", r.address)
	msg := sprintf("[sg-world-ingress] %s: ingress from the internet on admin or all ports is not allowed", [r.address])
}
