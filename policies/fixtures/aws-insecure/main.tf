# Deliberately insecure configuration. CI plans it (against LocalStack) and the policies must
# deny it with every rule ID listed in expected-denials.txt. Never apply this.
terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.44, < 7.0"
    }
  }
}

provider "aws" {
  region = "eu-west-1"
}

resource "aws_s3_bucket" "loose" {
  bucket = "my-test-bucket" # no public access block, no KMS encryption, bad Name
  tags   = { Name = "my-test-bucket" }
}

resource "aws_security_group" "ssh_open" {
  name = "ssh-open"
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ebs_volume" "plain" {
  availability_zone = "eu-west-1a"
  size              = 1
  encrypted         = false
}

resource "aws_iam_policy" "admin" {
  name = "everything"
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "*", Resource = "*" }]
  })
}

resource "aws_iam_user" "ci" {
  name = "ci"
}

resource "aws_iam_access_key" "ci" {
  user = aws_iam_user.ci.name
}

resource "aws_kms_key" "no_rotation" {
  description         = "no rotation"
  enable_key_rotation = false
}

resource "terraform_data" "runs_commands" {
  provisioner "local-exec" {
    command = "echo hello"
  }
}
