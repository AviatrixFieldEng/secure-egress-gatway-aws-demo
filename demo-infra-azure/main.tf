terraform {
  required_providers {
    aviatrix = {
      source  = "AviatrixSystems/aviatrix"
      version = ">=3.0"
    }
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}

provider "aviatrix" {
  skip_version_validation = true
}

provider "azurerm" {
  features {}
}

resource "random_pet" "rg_name" {
  prefix = "dcf-egress"
}

// Manages the Resource Group where the resource exists
resource "azurerm_resource_group" "default" {
  name     = "dcf-egress-RG-${random_pet.rg_name.id}"
  location = var.azure_region
}

data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}

resource "azurerm_virtual_network" "default" {
  name                = "dcf-egress-vnet"
  address_space       = ["10.100.0.0/20"]
  location            = var.azure_region
  resource_group_name = azurerm_resource_group.default.name
  tags = {
    VnetName = "dcf-egress-vnet"
  }
}

resource "azurerm_subnet" "public" {
  name                 = "public-subnet"
  resource_group_name  = azurerm_resource_group.default.name
  virtual_network_name = azurerm_virtual_network.default.name
  address_prefixes     = [cidrsubnet("10.100.0.0/20", 4, 0)]
}

resource "azurerm_subnet" "private" {
  count                = var.number_of_gateways
  name                 = "private-subnet-${count.index}"
  resource_group_name  = azurerm_resource_group.default.name
  virtual_network_name = azurerm_virtual_network.default.name
  address_prefixes     = [cidrsubnet("10.100.0.0/20", 4, count.index + 1)]
}

resource "azurerm_route_table" "private_subnets" {
  count               = var.number_of_gateways
  name                = "private_subnet_route_table_${count.index}"
  location            = azurerm_virtual_network.default.location
  resource_group_name = azurerm_resource_group.default.name

  route {
    name           = "Internet"
    address_prefix = "0.0.0.0/0"
    next_hop_type  = var.deploy_nat_gateway ? "Internet" : "None"
  }

  lifecycle {
    ignore_changes = [route]
  }
}

resource "azurerm_network_security_group" "app" {
  name                = "app-nsg"
  location            = azurerm_resource_group.default.location
  resource_group_name = azurerm_resource_group.default.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "ICMP"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Icmp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "default" {
  count                     = var.number_of_gateways
  subnet_id                 = azurerm_subnet.private[count.index].id
  network_security_group_id = azurerm_network_security_group.app.id
}

resource "azurerm_route_table" "public_subnets" {
  name                = "public_subnet_route_table"
  location            = azurerm_virtual_network.default.location
  resource_group_name = azurerm_resource_group.default.name

  lifecycle {
    ignore_changes = [route]
  }
}

resource "azurerm_subnet_route_table_association" "public" {
  subnet_id      = azurerm_subnet.public.id
  route_table_id = azurerm_route_table.public_subnets.id
}

resource "azurerm_subnet_route_table_association" "private" {
  count          = var.number_of_gateways
  subnet_id      = azurerm_subnet.private[count.index].id
  route_table_id = azurerm_route_table.private_subnets[count.index].id
}

resource "azurerm_public_ip" "default" {
  count               = var.deploy_nat_gateway ? 1 : 0
  name                = "natgateway-public-ip"
  resource_group_name = azurerm_resource_group.default.name
  location            = azurerm_resource_group.default.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_nat_gateway" "default" {
  count               = var.deploy_nat_gateway ? 1 : 0
  name                = "natgateway"
  location            = azurerm_resource_group.default.location
  resource_group_name = azurerm_resource_group.default.name
  sku_name            = "Standard"
}

resource "azurerm_nat_gateway_public_ip_association" "example" {
  count                = var.deploy_nat_gateway ? 1 : 0
  nat_gateway_id       = azurerm_nat_gateway.default[0].id
  public_ip_address_id = azurerm_public_ip.default[0].id
}

resource "azurerm_subnet_nat_gateway_association" "association" {
  count          = var.deploy_nat_gateway ? var.number_of_gateways : 0
  subnet_id      = azurerm_subnet.private[count.index].id
  nat_gateway_id = azurerm_nat_gateway.default[0].id
}

# ## Configure LB

resource "azurerm_public_ip" "lb" {
  name                = "lb-ip"
  location            = var.azure_region
  resource_group_name = azurerm_resource_group.default.name
  sku                 = "Standard"
  allocation_method   = "Static"
  domain_name_label   = random_pet.rg_name.id
}

resource "azurerm_lb" "default" {
  name                = "dcf-egress-lb"
  location            = azurerm_resource_group.default.location
  resource_group_name = azurerm_resource_group.default.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "LbPublicIP"
    public_ip_address_id = azurerm_public_ip.lb.id
  }
}

resource "azurerm_lb_backend_address_pool" "default" {
  count           = var.number_of_gateways
  loadbalancer_id = azurerm_lb.default.id
  name            = "BackendAddressPool${count.index + 1}"
}

resource "azurerm_lb_backend_address_pool_address" "default" {
  count                   = var.number_of_gateways
  name                    = "app-${count.index + 1}"
  backend_address_pool_id = azurerm_lb_backend_address_pool.default[count.index].id
  virtual_network_id      = azurerm_virtual_network.default.id
  ip_address              = azurerm_network_interface.test_app[count.index].private_ip_address
}

resource "azurerm_lb_probe" "http" {
  loadbalancer_id = azurerm_lb.default.id
  name            = "app-lb-probe-http"
  port            = 80
}

resource "azurerm_lb_probe" "ssh" {
  loadbalancer_id = azurerm_lb.default.id
  name            = "app-lb-probe-ssh"
  port            = 22
}

resource "azurerm_lb_rule" "default" {
  count                          = var.number_of_gateways
  loadbalancer_id                = azurerm_lb.default.id
  name                           = "AppHttp${count.index}"
  protocol                       = "Tcp"
  frontend_port                  = 80 + count.index
  backend_port                   = 80
  frontend_ip_configuration_name = "LbPublicIP"
  probe_id                       = azurerm_lb_probe.http.id
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.default[count.index].id]
}

resource "azurerm_lb_rule" "ssh" {
  count                          = var.number_of_gateways
  loadbalancer_id                = azurerm_lb.default.id
  name                           = "AppSSH${count.index}"
  protocol                       = "Tcp"
  frontend_port                  = 2200 + count.index
  backend_port                   = 22
  frontend_ip_configuration_name = "LbPublicIP"
  probe_id                       = azurerm_lb_probe.ssh.id
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.default[count.index].id]
}



# Deploy Test VM

data "cloudinit_config" "test_app_config" {
  count         = var.number_of_gateways
  gzip          = true
  base64_encode = true

  part {
    filename     = "vpc1_gatus.conf"
    content_type = "text/cloud-config"
    content      = templatefile("${path.module}/vpc1_cloud_init.tftpl", { admin_user = var.vm_admin_username, index = "${count.index + 1}" })
  }
}

resource "azurerm_network_interface" "test_app" {
  count = var.number_of_gateways

  name                = "test-app-nic-${count.index}"
  location            = azurerm_resource_group.default.location
  resource_group_name = azurerm_resource_group.default.name

  ip_configuration {
    name                          = "test-app-nic-config-${count.index}"
    subnet_id                     = azurerm_subnet.private[count.index].id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_virtual_machine" "test_app" {
  count = var.number_of_gateways

  name                             = "az-test-app-${count.index}"
  location                         = var.azure_region
  resource_group_name              = azurerm_resource_group.default.name
  network_interface_ids            = [azurerm_network_interface.test_app[count.index].id]
  vm_size                          = "Standard_B1s"
  delete_data_disks_on_termination = true
  delete_os_disk_on_termination    = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
  storage_os_disk {
    name              = "test-app-os-disk-${count.index}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = "az-test-app-${count.index}"
    admin_username = var.vm_admin_username
    admin_password = var.vm_admin_password
    custom_data    = data.cloudinit_config.test_app_config[0].rendered
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }
  tags = {
    Cloud       = "Azure"
    Application = "ConnectivityTest"
  }
  depends_on = [
    aviatrix_spoke_gateway.secure_egress
  ]
}

resource "aviatrix_spoke_gateway" "secure_egress" {
  cloud_type        = 8
  account_name      = var.aviatrix_azure_account
  gw_name           = "az-vpc1-${var.azure_region}"
  vpc_id            = "${azurerm_virtual_network.default.name}:${azurerm_resource_group.default.name}"
  vpc_reg           = var.aviatrix_azure_region
  gw_size           = var.gateway_size
  subnet            = azurerm_subnet.public.address_prefixes[0]
  zone              = "az-1"
  single_ip_snat    = false
  manage_ha_gateway = false
}

resource "aviatrix_spoke_ha_gateway" "secure_egress" {
  primary_gw_name = aviatrix_spoke_gateway.secure_egress.id
  gw_size         = var.gateway_size
  zone            = "az-1"
  subnet          = azurerm_subnet.public.address_prefixes[0]
}
