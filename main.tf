# Root module of the collection (askmohanty/hardened-modules/aws). It creates nothing: the building
# blocks are the submodules under modules/, used as `askmohanty/hardened-modules/aws//modules/<name>`.
# It exists because the Terraform Registry requires a root module, and it lists what the collection
# contains, read from the modules/ folder so new modules appear automatically.
locals {
  submodule_names = toset([for f in fileset(path.module, "modules/*/README.md") : split("/", f)[1]])

  submodules = {
    for name in local.submodule_names :
    name => trimspace(compact(split("\n", file("${path.module}/modules/${name}/README.md")))[1])
  }
}
