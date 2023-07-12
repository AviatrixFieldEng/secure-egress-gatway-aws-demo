resource "aviatrix_distributed_firewalling_policy_list" "distributed_firewalling_policy_list_1" {
  count = var.deploy_dcf_egress_policy ? 1 : 0

  # policies {
  #   name   = "Block-Known-Malicious"
  #   action = "DENY"
  #   src_smart_groups = [
  #     "def000ad-0000-0000-0000-000000000000"
  #   ]
  #   dst_smart_groups = [
  #     aviatrix_smart_group.threatiq.id
  #   ]
  #   priority                 = 0
  #   logging                  = true
  #   protocol                 = "ANY"
  #   watch                    = false
  #   flow_app_requirement     = "APP_UNSPECIFIED"
  #   decrypt_policy           = "DECRYPT_UNSPECIFIED"
  #   exclude_sg_orchestration = false
  # }

  policies {
    name   = "Egress-Allow-Web"
    action = "PERMIT"
    src_smart_groups = [
      aviatrix_smart_group.private_networks.id
    ]
    dst_smart_groups = [
      "def000ad-0000-0000-0000-000000000001"
    ]
    port_ranges {
      lo = 443
      hi = 0
    }
    port_ranges {
      lo = 80
      hi = 0
    }

    protocol = "TCP"
    logging  = true
    # web_groups = [
    #   aviatrix_web_group.demo_fqdn_allow.id
    # ]
    exclude_sg_orchestration = true
    priority                 = 1
    watch                    = false
    flow_app_requirement     = "APP_UNSPECIFIED"
    decrypt_policy           = "DECRYPT_UNSPECIFIED"
  }

  policies {
    name   = "Egress-Allow-ICMP"
    action = "PERMIT"
    src_smart_groups = [
      aviatrix_smart_group.private_networks.id
    ]
    dst_smart_groups = [
      "def000ad-0000-0000-0000-000000000001"
    ]

    protocol = "ICMP"
    logging  = true

    exclude_sg_orchestration = true
    priority                 = 2
    watch                    = false
    flow_app_requirement     = "APP_UNSPECIFIED"
    decrypt_policy           = "DECRYPT_UNSPECIFIED"
  }

  policies {
    name   = "CATCH-ALL-GLOBAL"
    action = "DENY"
    src_smart_groups = [
      "def000ad-0000-0000-0000-000000000000"
    ]
    dst_smart_groups = [
      "def000ad-0000-0000-0000-000000000000"
    ]
    priority                 = 2147483644
    logging                  = true
    exclude_sg_orchestration = true
    protocol                 = "ANY"
    watch                    = false
    flow_app_requirement     = "APP_UNSPECIFIED"
    decrypt_policy           = "DECRYPT_UNSPECIFIED"
  }

}

