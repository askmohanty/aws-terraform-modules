# S3: no public buckets, encryption at rest always on.
package aws.s3

import data.lib.plan
import rego.v1

full_public_access_block(module) if {
	some p in plan.by_type("aws_s3_bucket_public_access_block")
	plan.module_of(p) == module
	a := plan.after(p)
	a.block_public_acls == true
	a.block_public_policy == true
	a.ignore_public_acls == true
	a.restrict_public_buckets == true
}

kms_encrypted(module) if {
	some e in plan.by_type("aws_s3_bucket_server_side_encryption_configuration")
	plan.module_of(e) == module
	some rule in plan.after(e).rule
	some d in rule.apply_server_side_encryption_by_default
	d.sse_algorithm in {"aws:kms", "aws:kms:dsse"}
}

deny contains msg if {
	some b in plan.by_type("aws_s3_bucket")
	not full_public_access_block(plan.module_of(b))
	not plan.excepted("s3-public-access-block", b.address)
	msg := sprintf("[s3-public-access-block] %s: every bucket needs a public access block with all four settings true", [b.address])
}

deny contains msg if {
	some b in plan.by_type("aws_s3_bucket")
	not kms_encrypted(plan.module_of(b))
	not plan.excepted("s3-kms-encryption", b.address)
	msg := sprintf("[s3-kms-encryption] %s: every bucket needs default encryption with KMS (aws:kms or aws:kms:dsse)", [b.address])
}

deny contains msg if {
	some a in plan.by_type("aws_s3_bucket_acl")
	plan.after(a).acl in {"public-read", "public-read-write", "authenticated-read"}
	not plan.excepted("s3-public-acl", a.address)
	msg := sprintf("[s3-public-acl] %s: public bucket ACLs are not allowed", [a.address])
}
