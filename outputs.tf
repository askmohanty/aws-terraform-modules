output "submodules" {
  description = "Every module in the collection: its Registry source and what it is."
  value = {
    for name, summary in local.submodules : name => {
      source  = "askmohanty/hardened-modules/aws//modules/${name}"
      summary = summary
    }
  }
}
