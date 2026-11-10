# Databases and disks: encrypted, never public, protected from deletion in prod.
package aws.data_stores

import data.lib.plan
import rego.v1

deny contains msg if {
	some db in plan.by_type("aws_db_instance")
	plan.after(db).storage_encrypted != true
	not plan.excepted("rds-encryption", db.address)
	msg := sprintf("[rds-encryption] %s: RDS storage must be encrypted", [db.address])
}

deny contains msg if {
	some db in plan.by_type("aws_db_instance")
	plan.after(db).publicly_accessible == true
	not plan.excepted("rds-public", db.address)
	msg := sprintf("[rds-public] %s: RDS instances must not be publicly accessible", [db.address])
}

deny contains msg if {
	some db in plan.by_type("aws_rds_cluster")
	plan.after(db).storage_encrypted != true
	not plan.excepted("rds-encryption", db.address)
	msg := sprintf("[rds-encryption] %s: Aurora storage must be encrypted", [db.address])
}

deny contains msg if {
	some t in {"aws_db_instance", "aws_rds_cluster"}
	some db in plan.by_type(t)
	plan.is_prod(db)
	plan.after(db).deletion_protection != true
	not plan.excepted("rds-deletion-protection", db.address)
	msg := sprintf("[rds-deletion-protection] %s: prod databases need deletion_protection", [db.address])
}

deny contains msg if {
	some v in plan.by_type("aws_ebs_volume")
	plan.after(v).encrypted != true
	not plan.excepted("ebs-encryption", v.address)
	msg := sprintf("[ebs-encryption] %s: EBS volumes must be encrypted", [v.address])
}
