module "key_pair" {
  count  = var.deploy_aws_workloads ? 1 : 0
  source = "terraform-aws-modules/key-pair/aws"

  key_name           = "secure_egress_${random_string.name.result}"
  create_private_key = true
}

resource "aws_security_group" "allow_all_rfc1918" {
  count       = var.deploy_aws_tgw ? 2 : 1
  name        = "allow_all_rfc1918_vpc${count.index + 1}"
  description = "allow_all_rfc1918_vpc${count.index + 1}"
  vpc_id      = aws_vpc.default[count.index].id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_all_rfc1918_vpc${count.index + 1}"
  }
}

resource "aws_security_group" "allow_web_ssh_public" {
  count       = var.deploy_aws_workloads ? 1 : 0
  name        = "allow_web_ssh_public"
  description = "allow_web_ssh_public"
  vpc_id      = aws_vpc.default[0].id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.myip.response_body)}/32"]
  }
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 83
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.myip.response_body)}/32"]
  }
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.myip.response_body)}/32"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web_ssh_public"
  }
}

data "aws_ami" "amazon-linux-2" {
  most_recent = true

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-ebs"]
  }
}

data "aws_ami" "windows" {
  most_recent = true

  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }
}

data "aws_ami" "guacamole" {
  most_recent = true

  filter {
    name   = "owner-id"
    values = ["679593333241"]
  }

  filter {
    name   = "name"
    values = ["bitnami-guacamole-*-x86_64-hvm-ebs*"]
  }
}

# Deploy Guacamole AMI for remote desktop access to the Windows host in VPC1. Configuration happens in the separate "config-guacamole" Terraform plan
module "ec2_instance_guacamole" {
  count  = var.deploy_aws_workloads ? 1 : 0
  source = "terraform-aws-modules/ec2-instance/aws"

  name = "guacamole-01"

  ami                         = data.aws_ami.guacamole.image_id
  instance_type               = "t3a.small"
  key_name                    = module.key_pair[0].key_pair_name
  monitoring                  = true
  vpc_security_group_ids      = [aws_security_group.allow_web_ssh_public[0].id, aws_security_group.allow_all_rfc1918[0].id]
  subnet_id                   = aws_subnet.public_vpc1[0].id
  associate_public_ip_address = true

  tags = {
    Cloud       = "AWS"
    Application = "Bastion"
    Environment = "Prod"
  }

}

# Assign an EIP to Guacamole so that the URL doesn't change across reboots
resource "aws_eip" "guacamole" {
  count = var.deploy_aws_workloads ? 1 : 0
  vpc   = true

  instance                  = module.ec2_instance_guacamole[0].id
  associate_with_private_ip = module.ec2_instance_guacamole[0].private_ip

}

# Wait for the Guacamole instance to deploy
resource "time_sleep" "guacamole_ready" {
  count      = var.deploy_aws_workloads ? 1 : 0
  depends_on = [module.ec2_instance_guacamole]

  create_duration = "200s"
}

# SSH to the Guacamole instance and get the UI login
resource "ssh_resource" "guac_password" {
  count = var.deploy_aws_workloads ? 1 : 0
  # The default behaviour is to run file blocks and commands at create time
  # You can also specify 'destroy' to run the commands at destroy time
  when = "create"

  host        = aws_eip.guacamole[0].public_dns
  user        = "bitnami"
  private_key = module.key_pair[0].private_key_pem

  timeout = "15m"

  commands = [
    "sudo cat /home/bitnami/bitnami_credentials"
  ]
  depends_on = [
    time_sleep.guacamole_ready
  ]
}


## Wait for NAT GW's to be ready before deploying private workloads
resource "time_sleep" "egress_ready" {
  depends_on = [aws_nat_gateway.vpc1, aws_nat_gateway.vpc2]

  create_duration = "90s"
}

## Deploy Windows Jump Host in VPC1, AZ1
module "ec2_instance_windows" {
  count = var.deploy_aws_workloads ? 1 : 0

  source = "terraform-aws-modules/ec2-instance/aws"

  name = "windows-jump-${count.index + 1}"

  ami                         = data.aws_ami.windows.image_id
  instance_type               = "t3a.small"
  key_name                    = module.key_pair[0].key_pair_name
  monitoring                  = true
  vpc_security_group_ids      = [aws_security_group.allow_all_rfc1918[0].id]
  subnet_id                   = aws_subnet.private_vpc1[count.index].id
  associate_public_ip_address = false
  user_data                   = file("windows_init.txt")
  get_password_data           = true

  tags = {
    OS = "Windows"
  }
  depends_on = [
    time_sleep.egress_ready
  ]

}

## Deploy Linux Test Hosts in VPC1, All AZs running Gatus for connectivity testing
module "ec2_instance_vpc1" {
  count  = var.deploy_aws_workloads ? var.number_of_azs : 0
  source = "terraform-aws-modules/ec2-instance/aws"

  name = "vpc1-workload-${count.index}"

  ami                         = data.aws_ami.amazon-linux-2.image_id
  instance_type               = "t3a.micro"
  key_name                    = module.key_pair[0].key_pair_name
  monitoring                  = true
  vpc_security_group_ids      = [aws_security_group.allow_all_rfc1918[0].id]
  subnet_id                   = aws_subnet.private_vpc1[count.index].id
  user_data                   = var.deploy_aws_tgw ? templatefile("${path.module}/vpc1_test_server_tgw.tftpl", { vpc2_server = "${module.ec2_instance_vpc2[0].private_ip}", az = "${count.index + 1}" }) : templatefile("${path.module}/vpc1_test_server.tftpl", { az = "${count.index + 1}" })
  user_data_replace_on_change = true

  tags = {
    OS = "Linux"
  }

}

# Deploy an ELB to enable public access to web portal on the test Linux servers in VPC1
resource "aws_lb" "test-machine-ingress" {
  count              = var.deploy_aws_workloads ? 1 : 0
  name               = "avx-secure-egress"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_web_ssh_public[0].id]
  subnets            = [for v in aws_subnet.public_vpc1 : v.id]
}

resource "aws_lb_listener" "test-machine-ingress" {
  count             = var.deploy_aws_workloads ? var.number_of_azs : 0
  load_balancer_arn = aws_lb.test-machine-ingress[0].arn
  port              = "8${count.index}"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.test-machine-ingress[count.index].arn
  }
}

resource "aws_lb_target_group" "test-machine-ingress" {
  count       = var.deploy_aws_workloads ? var.number_of_azs : 0
  name        = "test-machine-${count.index}"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.default[0].id
  health_check {
    path                = "/"
    port                = 80
    healthy_threshold   = 6
    unhealthy_threshold = 2
    timeout             = 2
    interval            = 5
    matcher             = "200,302" # has to be HTTP 200 or fails
  }
}

resource "aws_lb_target_group_attachment" "test-machine-ingress" {
  count            = var.deploy_aws_workloads ? var.number_of_azs : 0
  target_group_arn = aws_lb_target_group.test-machine-ingress[count.index].arn
  target_id        = module.ec2_instance_vpc1[count.index].private_ip
  port             = 80
}


## Deploy Linux test host in VPC2, running a simple web server container to test connectivity across TGW
module "ec2_instance_vpc2" {
  count  = var.deploy_aws_tgw && var.deploy_aws_workloads ? 1 : 0
  source = "terraform-aws-modules/ec2-instance/aws"

  name = "vpc2-workload-${count.index}"

  ami                         = data.aws_ami.amazon-linux-2.image_id
  instance_type               = "t3a.micro"
  key_name                    = module.key_pair[0].key_pair_name
  monitoring                  = true
  vpc_security_group_ids      = [aws_security_group.allow_all_rfc1918[1].id]
  subnet_id                   = aws_subnet.private_vpc2[0].id
  user_data                   = file("${path.module}/vpc2_web_server.tftpl")
  user_data_replace_on_change = true

  tags = {
    OS = "Linux"
  }
}
