# Create an Aviatrix Spoke/Egress Gateways - Preferred Option for <=2 AZs in 7.0
resource "aviatrix_spoke_gateway" "secure_egress_vpc1" {
  count             = var.deploy_avx_egress_gateways && var.number_of_azs < 3 ? 1 : 0
  cloud_type        = 1
  account_name      = var.aviatrix_aws_account_name
  gw_name           = "avx-gateway-vpc1"
  vpc_id            = aws_vpc.default[0].id
  vpc_reg           = var.aws_region
  gw_size           = var.avx_gateway_size
  subnet            = aws_subnet.public_vpc1[0].cidr_block
  single_ip_snat    = var.enable_nat_avx_egress_gateways
  manage_ha_gateway = false
  depends_on = [
    aws_route_table_association.public_vpc1
  ]
}

resource "aviatrix_spoke_ha_gateway" "secure_egress_vpc1_ha" {
  count           = var.deploy_avx_egress_gateways && var.number_of_azs < 3 ? 1 : 0
  primary_gw_name = aviatrix_spoke_gateway.secure_egress_vpc1[0].id
  gw_size         = var.avx_gateway_size
  subnet          = aws_subnet.public_vpc1[count.index + 1].cidr_block
}

# Create an Aviatrix Standalone Gateways - Required for >2 AZs in 7.0
resource "aviatrix_gateway" "secure_egress_vpc1" {
  count        = var.deploy_avx_egress_gateways && var.number_of_azs > 2 ? var.number_of_azs : 0
  cloud_type   = 1
  account_name = var.aviatrix_aws_account_name
  gw_name      = "avx-gateway-vpc1-${count.index}"
  vpc_id       = aws_vpc.default[0].id
  vpc_reg      = var.aws_region
  gw_size      = var.avx_gateway_size
  subnet       = aws_subnet.public_vpc1[count.index].cidr_block
  depends_on = [
    aws_route_table_association.public_vpc1
  ]
}

# Aviatrix Statefull Firewall Policy - required for the demo to match FQDN and simultaneously enable Threatguard
resource "aviatrix_firewall" "firewall_1" {
  count                    = var.deploy_avx_egress_gateways && var.number_of_azs < 3 ? 1 : 0
  base_policy              = "deny-all"
  base_log_enabled         = false
  manage_firewall_policies = false
  gw_name                  = aviatrix_spoke_gateway.secure_egress_vpc1[count.index].gw_name
  depends_on = [
    aviatrix_spoke_gateway.secure_egress_vpc1, 
    aviatrix_spoke_ha_gateway.secure_egress_vpc1_ha
  ]
}

resource "aviatrix_firewall_policy" "firewall_policy_1" {
  count       = var.deploy_avx_egress_gateways && var.number_of_azs < 3 ? 1 : 0
  gw_name     = aviatrix_spoke_gateway.secure_egress_vpc1[count.index].gw_name
  src_ip      = "0.0.0.0/0"
  dst_ip      = "0.0.0.0/0"
  protocol    = "all"
  port        = ""
  action      = "allow"
  log_enabled = false
  description = "FQDN_Default"
  depends_on = [
    aviatrix_spoke_gateway.secure_egress_vpc1, 
    aviatrix_spoke_ha_gateway.secure_egress_vpc1_ha
  ]
}


# Create an Aviatrix Spoke/Egress Gateways in VPC2
resource "aviatrix_spoke_gateway" "secure_egress_vpc2" {
  count             = var.deploy_aws_tgw && var.deploy_avx_egress_gateways ? 1 : 0
  cloud_type        = 1
  account_name      = var.aviatrix_aws_account_name
  gw_name           = "avx-gateway-vpc2"
  vpc_id            = aws_vpc.default[1].id
  vpc_reg           = var.aws_region
  gw_size           = var.avx_gateway_size
  subnet            = aws_subnet.public_vpc2[0].cidr_block
  single_ip_snat    = var.enable_nat_avx_egress_gateways
  manage_ha_gateway = false
  depends_on = [
    aws_route_table_association.public_vpc2
  ]
}
