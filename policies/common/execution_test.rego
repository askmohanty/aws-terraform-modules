package common.execution_test

import data.common.execution
import rego.v1

cfg(resources) := {"configuration": {"root_module": {"module_calls": {"app": {"module": {"resources": resources}}}}}}

test_plain_resources_pass if {
	count(execution.deny) == 0 with input as cfg([{"address": "aws_sqs_queue.q", "mode": "managed", "type": "aws_sqs_queue"}])
}

test_local_exec_denied if {
	r := {"address": "null_resource.x", "mode": "managed", "type": "null_resource", "provisioners": [{"type": "local-exec"}]}
	some m in execution.deny with input as cfg([r])
	startswith(m, "[no-exec-provisioners]")
}

test_external_data_denied if {
	r := {"address": "data.external.x", "mode": "data", "type": "external"}
	some m in execution.deny with input as cfg([r])
	startswith(m, "[no-external-data]")
}
