# Root module of the collection (askmohanty/hardened-modules/aws). It creates nothing: the building blocks are
# the submodules under modules/, used as `askmohanty/hardened-modules/aws//modules/<name>`. It exists because
# the Terraform Registry requires a root module, and it lists what the collection contains.
locals {
  submodules = {
    naming    = "Resource names ({org}-{environment}-{region}-{name}) and standard tags"
    s3-bucket = "Private, encrypted, versioned S3 bucket"
  }
}
