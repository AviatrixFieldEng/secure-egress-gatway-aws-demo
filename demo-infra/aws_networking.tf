# Define the VPC and subnet CIDRs
variable "vpccidrs" {
  default = ["10.5.0.0/21", "10.6.0.0/21"]
}

locals {
  availability_zones = ["${var.aws_region}a", "${var.aws_region}b", "${var.aws_region}c"]

}

# Create the VPC
resource "aws_vpc" "default" {
  count      = var.deploy_aws_tgw ? 2 : 1
  cidr_block = var.vpccidrs[count.index]

  tags = {
    Name = "default-vpc-${count.index + 1}"
  }
}

# Create the internet gateway
resource "aws_internet_gateway" "default" {
  count  = var.deploy_aws_tgw ? 2 : 1
  vpc_id = aws_vpc.default[count.index].id

  tags = {
    Name = "default-igw-${count.index + 1}"
  }
}

# Create the public subnets VPC1
resource "aws_subnet" "public_vpc1" {
  count             = var.number_of_azs
  cidr_block        = cidrsubnet(var.vpccidrs[0], 3, count.index)
  vpc_id            = aws_vpc.default[0].id
  availability_zone = local.availability_zones[count.index]

  tags = {
    Name = "vpc1-public-${local.availability_zones[count.index]}"
  }
}

# Create the private subnets VPC1
resource "aws_subnet" "private_vpc1" {
  count             = var.number_of_azs
  cidr_block        = cidrsubnet(var.vpccidrs[0], 3, count.index + 3)
  vpc_id            = aws_vpc.default[0].id
  availability_zone = local.availability_zones[count.index]

  tags = {
    Name = "vpc1-private-${local.availability_zones[count.index]}"
  }
}

# Create the public subnets VPC2
resource "aws_subnet" "public_vpc2" {
  count             = var.deploy_aws_tgw ? 1 : 0
  cidr_block        = cidrsubnet(var.vpccidrs[1], 3, count.index)
  vpc_id            = aws_vpc.default[1].id
  availability_zone = local.availability_zones[count.index]

  tags = {
    Name = "vpc2-public-${local.availability_zones[count.index]}"
  }
}

# Create the private subnets VPC2
resource "aws_subnet" "private_vpc2" {
  count             = var.deploy_aws_tgw ? 1 : 0
  cidr_block        = cidrsubnet(var.vpccidrs[1], 3, count.index + 3)
  vpc_id            = aws_vpc.default[1].id
  availability_zone = local.availability_zones[count.index]

  tags = {
    Name = "vpc2-private-${local.availability_zones[count.index]}"
  }
}

# Create the EIPs for the NAT gateways
resource "aws_eip" "natgws" {
  count = var.deploy_aws_tgw ? var.number_of_azs + 1 : var.number_of_azs
  vpc   = true
  tags = {
    Name = "natgw-eip-${count.index}"
  }
}

# Create the NAT gateways for VPC1
resource "aws_nat_gateway" "vpc1" {
  count = var.number_of_azs

  allocation_id = aws_eip.natgws[count.index].id
  subnet_id     = aws_subnet.public_vpc1[count.index].id

  tags = {
    Name = "natgw-vpc1-${local.availability_zones[count.index]}"
  }
}

# Create the NAT gateways for VPC2
resource "aws_nat_gateway" "vpc2" {
  count = var.deploy_aws_tgw ? 1 : 0

  allocation_id = aws_eip.natgws[count.index + var.number_of_azs].id
  subnet_id     = aws_subnet.public_vpc2[count.index].id

  tags = {
    Name = "natgw-vpc2-${local.availability_zones[count.index]}"
  }
}

# Create the route tables for VPC1 without a TGW
resource "aws_route_table" "vpc1_public" {
  count  = var.deploy_aws_tgw ? 0 : var.number_of_azs
  vpc_id = aws_vpc.default[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.default[0].id
  }

  tags = {
    Name = "vpc1-public-rt-${local.availability_zones[count.index]}"
  }

lifecycle {
    ignore_changes = [route, ]
  }
}

resource "aws_route_table" "vpc1_private" {
count  = var.deploy_aws_tgw ? 0 : var.number_of_azs
  vpc_id = aws_vpc.default[0].id
 
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.vpc1[count.index].id
  }

  tags = {
    Name = "vpc1-private-rt-${local.availability_zones[count.index]}"
  }

  lifecycle {
    ignore_changes = [route, ]
  }
}

# Create the route tables for VPC1 with a TGW
resource "aws_route_table" "vpc1_public_tgw" {
count  = var.deploy_aws_tgw ? var.number_of_azs : 0
  vpc_id = aws_vpc.default[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.default[0].id
  }

  route {
    cidr_block = "10.0.0.0/8"
    transit_gateway_id = aws_ec2_transit_gateway.transit_gateway[0].id
  }

  tags = {
    Name = "vpc1-public-rt-${local.availability_zones[count.index]}"
  }

  lifecycle {
    ignore_changes = [route, ]
  }
}

resource "aws_route_table" "vpc1_private_tgw" {
count  = var.deploy_aws_tgw ? var.number_of_azs : 0
  vpc_id = aws_vpc.default[0].id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.vpc1[count.index].id
  }

route {
    cidr_block = "10.0.0.0/8"
    transit_gateway_id = aws_ec2_transit_gateway.transit_gateway[0].id
  }

  tags = {
    Name = "vpc1-private-rt-${local.availability_zones[count.index]}"
  }

  lifecycle {
    ignore_changes = [route, ]
  }
}


# Associate the subnets with the route tables for VPC1
resource "aws_route_table_association" "public_vpc1" {
  count = var.number_of_azs

  subnet_id      = aws_subnet.public_vpc1[count.index].id
  route_table_id = var.deploy_aws_tgw ? aws_route_table.vpc1_public_tgw[count.index].id : aws_route_table.vpc1_public[count.index].id
}

resource "aws_route_table_association" "private_vpc1" {
  count = var.number_of_azs

  subnet_id      = aws_subnet.private_vpc1[count.index].id
  route_table_id = var.deploy_aws_tgw ?  aws_route_table.vpc1_private_tgw[count.index].id : aws_route_table.vpc1_private[count.index].id
}


# Create the route tables for VPC2
resource "aws_route_table" "vpc2_public" {
  count  = var.deploy_aws_tgw ? 1 : 0
  vpc_id = aws_vpc.default[1].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.default[1].id
  }
  route {
    cidr_block = "10.0.0.0/8"
    transit_gateway_id = aws_ec2_transit_gateway.transit_gateway[0].id
  }

  tags = {
    Name = "vpc2-public-rt-${local.availability_zones[count.index]}"
  }

  lifecycle {
    ignore_changes = [route, ]
  }
}

resource "aws_route_table" "vpc2_private" {
  count  = var.deploy_aws_tgw ? 1 : 0
  vpc_id = aws_vpc.default[1].id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.vpc2[count.index].id
  }

    route {
    cidr_block = "10.0.0.0/8"
    transit_gateway_id = aws_ec2_transit_gateway.transit_gateway[0].id
  }

  tags = {
    Name = "vpc2-private-rt-${local.availability_zones[count.index]}"
  }

  lifecycle {
    ignore_changes = [route, ]
  }
}

# Associate the subnets with the route tables for VPC2
resource "aws_route_table_association" "public_vpc2" {
  count = var.deploy_aws_tgw ? 1 : 0

  subnet_id      = aws_subnet.public_vpc2[count.index].id
  route_table_id = aws_route_table.vpc2_public[count.index].id
}

resource "aws_route_table_association" "private_vpc2" {
  count = var.deploy_aws_tgw ? 1 : 0

  subnet_id      = aws_subnet.private_vpc2[count.index].id
  route_table_id = aws_route_table.vpc2_private[count.index].id
}


# Create the Transit Gateway
resource "aws_ec2_transit_gateway" "transit_gateway" {
  count       = var.deploy_aws_tgw ? 1 : 0
  description = "Transit Gateway"
  tags = {
    Name = "Transit Gateway"
  }
}

# Attach the VPC1 to TGW
resource "aws_ec2_transit_gateway_vpc_attachment" "vpc1" {
    count = var.deploy_aws_tgw ? 1 : 0
  transit_gateway_id = aws_ec2_transit_gateway.transit_gateway[0].id
  vpc_id             = aws_vpc.default[0].id
  subnet_ids = [ for v in  aws_subnet.private_vpc1 : v.id]
}

# Attach the VPC2 to TGW
resource "aws_ec2_transit_gateway_vpc_attachment" "vpc2" {
    count = var.deploy_aws_tgw ? 1 : 0
  transit_gateway_id = aws_ec2_transit_gateway.transit_gateway[0].id
  vpc_id             = aws_vpc.default[1].id
  subnet_ids = [ for v in  aws_subnet.private_vpc2 : v.id]
}