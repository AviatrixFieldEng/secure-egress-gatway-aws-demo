variable "aviatrix_aws_account_name" {
  description = "Aviatrix AWS Account Name"
}

# variable "aws_key_pair_name" {
#   description = "AWS Key Pair Name"
# }

variable "deploy_aws_tgw" {
  type = bool
  description = "Deploys a second VPC and a TGW to attach to the VPC.  This is to demonstrate seamless integration of Aviatrix Secure Egress into an existing transit architecture."
  default = true
}

variable "deploy_aws_workloads" {
  type = bool
  description = "Deploy workloads in the AWS VPCs for testing connectivity and FQDN filtering."
  default = true
}

variable "number_of_azs" {
  description = "Number of Availability Zones in each VPC"
  default = 2
}

variable "deploy_avx_egress_gateways" {
  type = bool
  description = "Stage the deployment of Aviatrix Gateways in VPC 1"
  default = true
}

variable "enable_nat_avx_egress_gateways" {
  type = bool
  description = "Enable NAT on the Aviatrix Egress Gateways"
  default = false
}

variable "deploy_avx_egress_policy" {
  type = bool
  description = "Deploy a Aviatrix Secure Egress configuration leveraging the legacy FQDN Egress policy configuration."
  default = false
}

variable "tags" {
  description = "A map of the tags to use for the resources that are deployed."
  type        = map(string)

  default = {
    avxlab = "microseg"
  }
}

variable "aws_region" {
  description = "AWS Region"
  default     = "us-east-2"
}