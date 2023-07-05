resource "aviatrix_smart_group" "private_networks" {
  name = "Private-Networks"
  selector {
    match_expressions {
      cidr = "10.0.0.0/8"
    }
    match_expressions {
      cidr = "172.16.0.0/12"
    }
  }
}

resource "aviatrix_smart_group" "aws_egress_vpc" {
  name = "AWS-Egress-Demo-VPC"
  selector {
    match_expressions {
      type = "vpc"
      tags = {
        Name = "egress-demo-vpc-1"
      }
    }
  }
}

resource "aviatrix_smart_group" "aws_egress_vpc" {
  name = "ThreatIQ-Blocklist"
  selector {
    match_expressions {
      cidr = "172.16.0.0/12"
    }
  }
}

resource "aviatrix_web_group" "vpc1_allow" {
  name = "vpc1_allow"
  selector {
    match_expressions {
      snifilter = "portal.azure.com"
    }
    match_expressions {
      snifilter = "*.amazon.com"
    }
    match_expressions {
      snifilter = "*.google.com"
    }
  }
}

resource "aviatrix_web_group" "facebook" {
  name = "facebook"
  selector {
    match_expressions {
      snifilter = "*.facebook.com"
    }
  }
}

