# Unit tests: each rule must pass a good plan and catch a known-bad one.
package aws_test

import data.aws.data_stores
import data.aws.iam_kms
import data.aws.network
import data.aws.s3
import data.aws.tagging
import rego.v1

rc(type, address, module, after) := {
	"type": type,
	"address": address,
	"module_address": module,
	"change": {"actions": ["create"], "after": after},
}

good_tags := {"Name": "acme-dev-euw1-orders", "Org": "acme", "Environment": "dev", "ManagedBy": "terraform"}

prod_tags := object.union(good_tags, {"Name": "acme-prod-euw1-orders", "Environment": "prod"})

pab(module, all_true) := rc("aws_s3_bucket_public_access_block", sprintf("%s.aws_s3_bucket_public_access_block.this", [module]), module, {
	"block_public_acls": all_true, "block_public_policy": true,
	"ignore_public_acls": true, "restrict_public_buckets": true,
})

sse(module, algorithm) := rc("aws_s3_bucket_server_side_encryption_configuration", sprintf("%s.sse", [module]), module, {"rule": [{"apply_server_side_encryption_by_default": [{"sse_algorithm": algorithm}]}]})

bucket(module) := rc("aws_s3_bucket", sprintf("%s.aws_s3_bucket.this", [module]), module, {"tags": good_tags})

# ---- S3

test_secure_bucket_passes if {
	count(s3.deny) == 0 with input as {"resource_changes": [bucket("module.b"), pab("module.b", true), sse("module.b", "aws:kms")]}
}

test_bucket_without_public_access_block_denied if {
	some m in s3.deny with input as {"resource_changes": [bucket("module.b"), sse("module.b", "aws:kms")]}
	startswith(m, "[s3-public-access-block]")
}

test_partial_public_access_block_denied if {
	some m in s3.deny with input as {"resource_changes": [bucket("module.b"), pab("module.b", false), sse("module.b", "aws:kms")]}
	startswith(m, "[s3-public-access-block]")
}

test_aes256_only_bucket_denied if {
	some m in s3.deny with input as {"resource_changes": [bucket("module.b"), pab("module.b", true), sse("module.b", "AES256")]}
	startswith(m, "[s3-kms-encryption]")
}

test_public_acl_denied if {
	some m in s3.deny with input as {"resource_changes": [rc("aws_s3_bucket_acl", "aws_s3_bucket_acl.a", "", {"acl": "public-read"})]}
	startswith(m, "[s3-public-acl]")
}

# ---- Network

sg(ingress) := rc("aws_security_group", "aws_security_group.web", "", {"ingress": [ingress], "tags": good_tags})

test_https_from_world_allowed if {
	count(network.deny) == 0 with input as {"resource_changes": [sg({"protocol": "tcp", "from_port": 443, "to_port": 443, "cidr_blocks": ["0.0.0.0/0"]})]}
}

test_ssh_from_world_denied if {
	some m in network.deny with input as {"resource_changes": [sg({"protocol": "tcp", "from_port": 22, "to_port": 22, "cidr_blocks": ["0.0.0.0/0"]})]}
	startswith(m, "[sg-world-ingress]")
}

test_rdp_inside_a_wide_range_denied if {
	some m in network.deny with input as {"resource_changes": [sg({"protocol": "tcp", "from_port": 3000, "to_port": 4000, "ipv6_cidr_blocks": ["::/0"]})]}
	startswith(m, "[sg-world-ingress]")
}

test_all_traffic_from_world_denied if {
	some m in network.deny with input as {"resource_changes": [rc("aws_vpc_security_group_ingress_rule", "aws_vpc_security_group_ingress_rule.all", "", {"cidr_ipv4": "0.0.0.0/0", "ip_protocol": "-1"})]}
	startswith(m, "[sg-world-ingress]")
}

test_ssh_from_office_allowed if {
	count(network.deny) == 0 with input as {"resource_changes": [sg({"protocol": "tcp", "from_port": 22, "to_port": 22, "cidr_blocks": ["203.0.113.0/24"]})]}
}

# ---- Databases and disks

db(after) := rc("aws_db_instance", "module.db.aws_db_instance.this", "module.db", after)

test_secure_dev_db_passes if {
	count(data_stores.deny) == 0 with input as {"resource_changes": [db({"storage_encrypted": true, "publicly_accessible": false, "deletion_protection": false, "tags": good_tags})]}
}

test_unencrypted_db_denied if {
	some m in data_stores.deny with input as {"resource_changes": [db({"storage_encrypted": false, "publicly_accessible": false, "tags": good_tags})]}
	startswith(m, "[rds-encryption]")
}

test_public_db_denied if {
	some m in data_stores.deny with input as {"resource_changes": [db({"storage_encrypted": true, "publicly_accessible": true, "tags": good_tags})]}
	startswith(m, "[rds-public]")
}

test_prod_db_without_deletion_protection_denied if {
	some m in data_stores.deny with input as {"resource_changes": [db({"storage_encrypted": true, "publicly_accessible": false, "deletion_protection": false, "tags": prod_tags})]}
	startswith(m, "[rds-deletion-protection]")
}

test_unencrypted_ebs_denied if {
	some m in data_stores.deny with input as {"resource_changes": [rc("aws_ebs_volume", "aws_ebs_volume.v", "", {"encrypted": false})]}
	startswith(m, "[ebs-encryption]")
}

# ---- IAM and KMS

iam_policy(doc) := rc("aws_iam_policy", "aws_iam_policy.p", "", {"policy": json.marshal(doc)})

test_scoped_iam_policy_passes if {
	count(iam_kms.deny) == 0 with input as {"resource_changes": [iam_policy({"Version": "2012-10-17", "Statement": [{"Effect": "Allow", "Action": ["s3:GetObject"], "Resource": "arn:aws:s3:::b/*"}]})]}
}

test_wildcard_admin_denied if {
	some m in iam_kms.deny with input as {"resource_changes": [iam_policy({"Version": "2012-10-17", "Statement": {"Effect": "Allow", "Action": "*", "Resource": "*"}})]}
	startswith(m, "[iam-wildcard-admin]")
}

test_access_key_denied if {
	some m in iam_kms.deny with input as {"resource_changes": [rc("aws_iam_access_key", "aws_iam_access_key.ci", "", {})]}
	startswith(m, "[iam-access-key]")
}

test_kms_without_rotation_denied if {
	some m in iam_kms.deny with input as {"resource_changes": [rc("aws_kms_key", "aws_kms_key.k", "", {"enable_key_rotation": false})]}
	startswith(m, "[kms-rotation]")
}

test_asymmetric_kms_key_exempt_from_rotation if {
	count(iam_kms.deny) == 0 with input as {"resource_changes": [rc("aws_kms_key", "aws_kms_key.k", "", {"enable_key_rotation": false, "customer_master_key_spec": "RSA_2048"})]}
}

# ---- Tags and naming

test_conventional_tags_pass if {
	count(tagging.deny) == 0 with input as {"resource_changes": [bucket("module.b")]}
}

test_untagged_resource_denied if {
	some m in tagging.deny with input as {"resource_changes": [rc("aws_sqs_queue", "aws_sqs_queue.q", "", {"tags": null})]}
	startswith(m, "[required-tags]")
}

test_bad_name_denied if {
	tags := object.union(good_tags, {"Name": "my-test-bucket"})
	some m in tagging.deny with input as {"resource_changes": [rc("aws_sqs_queue", "aws_sqs_queue.q", "", {"tags": tags})]}
	startswith(m, "[naming]")
}

test_unknown_environment_denied if {
	tags := object.union(good_tags, {"Name": "acme-qa-euw1-orders", "Environment": "qa"})
	some m in tagging.deny with input as {"resource_changes": [rc("aws_sqs_queue", "aws_sqs_queue.q", "", {"tags": tags})]}
	startswith(m, "[naming]")
}

test_org_config_extends_environments if {
	tags := object.union(good_tags, {"Name": "acme-qa-euw1-orders", "Environment": "qa"})
	count(tagging.deny) == 0 with input as {"resource_changes": [rc("aws_sqs_queue", "aws_sqs_queue.q", "", {"tags": tags})]}
		with data.naming.environments as ["dev", "qa", "prod"]
}

test_tags_from_provider_default_tags_count if {
	resource := rc("aws_sqs_queue", "aws_sqs_queue.q", "", {
		"tags": {"Name": "acme-dev-euw1-orders", "ManagedBy": "terraform"},
		"tags_all": good_tags,
	})
	count(tagging.deny) == 0 with input as {"resource_changes": [resource]}
}

test_untaggable_resource_ignored if {
	count(tagging.deny) == 0 with input as {"resource_changes": [pab("module.b", true)]}
}

# ---- Exceptions

ssh_rule := sg({"protocol": "tcp", "from_port": 22, "to_port": 22, "cidr_blocks": ["0.0.0.0/0"]})

test_valid_exception_waives_rule if {
	count(network.deny) == 0 with input as {"resource_changes": [ssh_rule]}
		with data.exceptions as [{"rule": "sg-world-ingress", "address": "aws_security_group.web", "reason": "bastion migration", "approved_by": "security", "expires": "2099-01-01T00:00:00Z"}]
}

test_expired_exception_does_not_waive_rule if {
	count(network.deny) == 1 with input as {"resource_changes": [ssh_rule]}
		with data.exceptions as [{"rule": "sg-world-ingress", "address": "aws_security_group.web", "reason": "old", "approved_by": "security", "expires": "2020-01-01T00:00:00Z"}]
}

test_exception_is_scoped_to_one_rule if {
	count(network.deny) == 1 with input as {"resource_changes": [ssh_rule]}
		with data.exceptions as [{"rule": "naming", "address": "aws_security_group.web", "reason": "x", "approved_by": "y", "expires": "2099-01-01T00:00:00Z"}]
}
