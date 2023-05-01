resource "aviatrix_distributed_firewalling_policy_list" "distributed_firewalling_policy_list_1" {
    count = var.deploy_dfw_egress_policy ? 1: 0
    policies {
        name = "Private-Policy"
        action = "PERMIT"
        src_smart_groups = [ 
            aviatrix_smart_group.private_networks.id
        ]
        dst_smart_groups = [ 
            aviatrix_smart_group.private_networks.id
        ]
        priority = 0
        protocol = "ANY"
        logging = false
        watch = false
    }

    policies {
        name = "Egress-Internet-TLS"
        action = "PERMIT"
        src_smart_groups = [ 
            aviatrix_smart_group.private_networks.id
        ]
        dst_smart_groups = [ 
            aviatrix_smart_group.internet.id
        ]
        port_ranges {
            lo = 443
            hi = 0
        }

        priority = 1
        protocol = "TCP"
        logging = true
        watch = false
    }

    policies {
        name = "Egress-Internet-HTTP"
        action = "PERMIT"
        src_smart_groups = [ 
            aviatrix_smart_group.private_networks.id
        ]
        dst_smart_groups = [ 
            aviatrix_smart_group.internet.id
        ]
        port_ranges {
            lo = 80
            hi = 0
        }

        priority = 2
        protocol = "TCP"
        logging = true
        watch = false
    }

}

