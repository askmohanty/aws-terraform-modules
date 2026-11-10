# IAM and KMS: no admin wildcards, no long-lived keys, key rotation on.
package aws.iam_kms

import data.lib.plan
import rego.v1

policy_types := {"aws_iam_policy", "aws_iam_role_policy", "aws_iam_user_policy", "aws_iam_group_policy"}

as_list(x) := x if is_array(x)

as_list(x) := [x] if not is_array(x)

wildcard_admin(doc) if {
	some s in as_list(doc.Statement)
	s.Effect == "Allow"
	"*" in as_list(object.get(s, "Action", []))
	"*" in as_list(object.get(s, "Resource", []))
}

deny contains msg if {
	some t in policy_types
	some p in plan.by_type(t)
	wildcard_admin(json.unmarshal(plan.after(p).policy))
	not plan.excepted("iam-wildcard-admin", p.address)
	msg := sprintf("[iam-wildcard-admin] %s: \"Action: *\" on \"Resource: *\" is not allowed; grant specific actions", [p.address])
}

deny contains msg if {
	some k in plan.by_type("aws_iam_access_key")
	not plan.excepted("iam-access-key", k.address)
	msg := sprintf("[iam-access-key] %s: long-lived access keys are not allowed; use roles (e.g. GitHub OIDC)", [k.address])
}

deny contains msg if {
	some k in plan.by_type("aws_kms_key")
	a := plan.after(k)
	object.get(a, "customer_master_key_spec", "SYMMETRIC_DEFAULT") == "SYMMETRIC_DEFAULT"
	a.enable_key_rotation != true
	not plan.excepted("kms-rotation", k.address)
	msg := sprintf("[kms-rotation] %s: symmetric KMS keys need automatic rotation", [k.address])
}
