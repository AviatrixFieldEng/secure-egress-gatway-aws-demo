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
  controller_ip           = var.controller_ip
  username                = var.username
  password                = var.password
}

provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key != "dummy" ? var.aws_access_key : null
  secret_key = var.aws_access_key_secret != "dummy" ? var.aws_access_key_secret : null
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
