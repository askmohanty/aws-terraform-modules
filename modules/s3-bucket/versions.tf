terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # The wrapped terraform-aws-modules/s3-bucket v5.17.0 needs >= 6.44.
      version = ">= 6.44, < 7.0"
    }
  }
}
