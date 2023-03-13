terraform {
  required_providers {
    aviatrix = {
      source  = "AviatrixSystems/aviatrix"
      version = ">=3.0"
    }
    aws = {
      source = "hashicorp/aws"
    }
    ssh = {
      source = "loafoe/ssh"
    }
  }
}

provider "aviatrix" {
  skip_version_validation = true
}

provider "aws" {
  region = var.aws_region
}

// Generate random value for the name
resource "random_string" "name" {
  length  = 8
  upper   = false
  lower   = true
  special = false
}

data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}
