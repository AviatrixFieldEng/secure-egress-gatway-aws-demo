terraform {
  required_providers {
    guacamole = {
      source = "techBeck03/guacamole"
    }
  }
}

provider "guacamole" {
  url                      = "https://${var.guacamole_fqdn}"
  username                 = var.guacamole_username
  password                 = var.guacamole_password
  disable_tls_verification = true
  disable_cookies          = true
}

resource "guacamole_connection_rdp" "aws_vdi" {
  for_each = { for record in var.vpc1_windows_instances : record.name => record }

  name = each.value.name
  parameters {
    hostname      = each.value["ip"]
    username      = "Administrator"
    password      = each.value.password
    port          = 3389
    security_mode = "any"
    ignore_cert   = true
  }
  attributes {
    failover_only = false
  }
}