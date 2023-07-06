variable "azure_region" {
  description = "Azure Region"
  default     = "eastus"
}

variable "aviatrix_azure_region" {
  description = "Aviatrix Azure Region"
  default = "East US"
  
}

variable "aviatrix_azure_account" {
  description = "Aviatrix Azure Account"
  default     = "my-account"
}

variable "gateway_size" {
  description = "Aviatrix gateway size"
  default     = "Standard_B2ms"
}

variable "number_of_gateways" {
  default = 2
}

variable "vm_admin_username" {
  default = "avxadmin"
}

variable "vm_admin_password" {
  default = "Aviatrix12345#"
}

variable "deploy_nat_gateway" {
  default = true
}

variable "deploy_aviatrix_gateway" {
  default = true
}

variable "enable_aviatrix_nat" {
  default = false
}