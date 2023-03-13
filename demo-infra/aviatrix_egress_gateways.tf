resource "aviatrix_spoke_gateway" "secure_egress_vpc1" {
  count             = var.deploy_avx_egress_gateways && var.number_of_azs < 3 ? 1 : 0
  cloud_type        = 1
  account_name      = var.aviatrix_aws_account_name
  gw_name           = "avx-gateway-vpc1"
  vpc_id            = aws_vpc.default[0].id
  vpc_reg           = var.aws_region
  gw_size           = "t3.micro"
  subnet            = aws_subnet.public_vpc1[0].cidr_block
  single_ip_snat    = var.enable_nat_avx_egress_gateways
  manage_ha_gateway = false
}

resource "aviatrix_spoke_ha_gateway" "secure_egress_vpc1_ha" {
  count           = var.deploy_avx_egress_gateways && var.number_of_azs < 3 ? 1 : 0
  primary_gw_name = aviatrix_spoke_gateway.secure_egress_vpc1[0].id
  subnet          = aws_subnet.public_vpc1[count.index + 1].cidr_block
}

# Create an Aviatrix AWS Gateway
resource "aviatrix_gateway" "secure_egress_vpc1" {
    count = var.deploy_avx_egress_gateways && var.number_of_azs > 2 ? var.number_of_azs : 0
  cloud_type   = 1
  account_name = var.aviatrix_aws_account_name
  gw_name      = "avx-gateway-vpc1-${count.index}"
  vpc_id       = aws_vpc.default[0].id
  vpc_reg      = var.aws_region
  gw_size      = "t3.micro"
  subnet       = aws_subnet.public_vpc1[count.index].cidr_block
}

resource "aviatrix_spoke_gateway" "secure_egress_vpc2" {
  count             = var.deploy_aws_tgw && var.deploy_avx_egress_gateways ? 1 : 0
  cloud_type        = 1
  account_name      = var.aviatrix_aws_account_name
  gw_name           = "avx-gateway-vpc2"
  vpc_id            = aws_vpc.default[1].id
  vpc_reg           = var.aws_region
  gw_size           = "t3.micro"
  subnet            = aws_subnet.public_vpc2[0].cidr_block
  single_ip_snat    = var.enable_nat_avx_egress_gateways
  manage_ha_gateway = false
}