# Tags and naming: every taggable resource carries the required tags and a conventional Name.
package aws.tagging

import data.lib.plan
import rego.v1

name_pattern := sprintf("^%s-(%s)-[a-z0-9]+-[a-z0-9-]+$", [plan.org_pattern, concat("|", plan.environments)])

# A resource is taggable when its planned attributes include a `tags` key.
taggable contains rc if {
	some rc in plan.changes
	"tags" in object.keys(plan.after(rc))
}

tags_of(rc) := t if {
	t := plan.after(rc).tags
	t != null
} else := {}

deny contains msg if {
	some rc in taggable
	some tag in plan.required_tags
	not tags_of(rc)[tag]
	not plan.excepted("required-tags", rc.address)
	msg := sprintf("[required-tags] %s: missing tag %q", [rc.address, tag])
}

deny contains msg if {
	some rc in taggable
	name := tags_of(rc).Name
	not regex.match(name_pattern, name)
	not plan.excepted("naming", rc.address)
	msg := sprintf("[naming] %s: Name %q does not follow {org}-{environment}-{region}-{name}", [rc.address, name])
}

deny contains msg if {
	some rc in taggable
	env := tags_of(rc).Environment
	not env in plan.environments
	not plan.excepted("naming", rc.address)
	msg := sprintf("[naming] %s: Environment %q is not one of %v", [rc.address, env, plan.environments])
}
