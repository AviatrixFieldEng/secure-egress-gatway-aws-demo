aviatrix_aws_account_name      = "aws-avx"
aws_region                     = "us-east-2"
deploy_aws_tgw                 = true
deploy_aviatrix_transit        = false
deploy_aws_workloads           = true
deploy_avx_egress_gateways     = true
enable_nat_avx_egress_gateways = false
deploy_avx_egress_policy       = false
deploy_dfw_egress_policy       = true
avx_gateway_size               = "t3.medium"
number_of_azs                  = 2

# Below only needed if controller is not in AWS
# Please uncomment and fill in with your own key and secret
# aws_access_key        = "Your AWS key"
# aws_access_key_secret = "Your AWS key secret"

# Below is optionnal, you can just provide values on the fly at deployment time
# controller_ip = "Your controller IP address"
# username      = "Your controller login"
# password      = "Your controller password"
