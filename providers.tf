terraform {
  required_version = ">= 1.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    # AWS DevOps Agent resources are currently exposed through the AWS Cloud
    # Control provider rather than the standard AWS provider.
    awscc = {
      source  = "hashicorp/awscc"
      version = "~> 1.101"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }

    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }

  cloud {
    organization = "smdevops96_org"

    workspaces {
      name = "amazon-devops-terraform"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "awscc" {
  region = var.aws_region
}
