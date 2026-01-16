terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket = "gdanca-3tier-stack"
    key    = "state-file-folder"
    region = "eu-central-1"
  }
}

