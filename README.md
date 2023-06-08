# Distributed Cloud Firewall for Egress - AWS Demo
Terraform config to demonstrate a basic Aviatrix Distributed Cloud Firewall gateway replacing an AWS NAT Gateway.

# Quick Start

Clone the repository.

```
git clone https://github.com/AviatrixFieldEng/secure-egress-gatway-aws-demo.git
cd secure-egress-gateway-aws-demo/demo-infra
```

Pre-reqs: Controller v7.0+, Terraform Provider v3.0+

YOU MUST ALSO SUBSCRIBE TO THE BITNAMI GUACAMOLE IMAGE ON AWS MARKETPLACE: https://aws.amazon.com/marketplace/pp/prodview-qfe3iaudofb5q

### Deploy the Topology

Update var.tfvars to match your configuration.

```
terraform init
terraform plan --var-file=var.tfvars
terraform apply --var-file=var.tfvars
```

Open the URLs in the output `test_machine_ui` to verify that the deployment was successful.


### Configure Guacamole for Windows server access

Copy the output from the previous Terraform apply.  To `/config-guacamole/var.tfvars`.

```
cd ..
cd config-guacamole
terraform init
terraform apply --var-file=var.tfvars
```

Log into Guacamole with the link from the `guacamole_login_url` in the initial apply.


# Demo Topology

The demonstration topology is designed to show a Distributed Cloud Firewall for Egress design that replaces AWS NAT gateways.  Optionally the environment can be deployed where 2 VPCs are connected to an AWS Transit Gateway to demonstrate that deploying Aviatrix Distributed Cloud Firewall for Egress does not impact an existing transit network deployment.

In the demo, we will be securing VPC1.  The terraform allows a configurable number of AZs for VPC1 to demonstrate how Distributed Cloud Firewall for Egress optimizes traffic to stay within an AZ and can support 2+ AZs.

There are 4 types of machines that are deployed to allow for traffic simulation:

1. **VPC1 Windows:** 1 Windows machine is deployed in AZ1 in a private subnet.  This machine can be accessesed via the guacamole jump server and can be used to demonstrate custom policies via a Web Browser.

2. **VPC1 Linux Traffic Simulators:** 1 Linux Traffic simulator will be deployed in each AZ of VPC1 in private subnets.  These machines run Gatus (https://github.com/TwiN/gatus) and are configured to constantly test access to several internet URLs, a ToR exit node (to demonstrate threat blocking) and a web server in VPC2, if TGW is deployed, to demonstrate transit connectivity.

3. **VPC1 Guacamole:** Guacamole is an HTTP-based remote access application.  This is deployed in AZ1 of VPC1 in a public subnet to allow access to the Windows server.  Guacamole needs to be configured after the deployment of the infrastructure.  Configuration is described below.

4. **VPC2 Linux Web Server:** 1 Linux web server will be deployed in VPC2 to enable traffic simulation across the transit.

The deployment will also configure a public-facing ELB to provide access to the web-ui for the traffic simulators in VPC1.

Security groups are configured for all machines.  For public facing services, the Terraform provider will pinhole an allow rule for the IP from which the Terraform deployment was initiated.


# Deploying the Lab Environment

```
cd demo-infra
```

Edit `var.tfvars` with your variables:

* `aviatrix_aws_account_name`: The name of the AWS account in the Aviatrix controller with which you want to deploy the Egress Gateways

* `aws_region`: Region to deploy the lab environment. Defaults to `us-east-1`

* `deploy_aws_tgw`: Deploy a TGW and VPC2 to demonstrate that Distributed Cloud Firewall for Egress can be seamlessly deployed with an existing transit and distributed NAT gateways.

* `deploy_aws_workloads`: Deploy workloads in the network to simulate traffic.

* `deploy_avx_egress_gateways`: Stage the deployment of Aviatrix Egress gateways in VPC1 and VPC2

* `enable_nat_avx_egress_gateways`: Configure SNAT on the Aviatrix Egress gateways to automatically replace the AWS NAT Gateways. This can be done via Terraform or manually in the GUI depending on whether the customer wants to see programmatic configuration or Click Ops.

* `number_of_azs`: Number of AZs in VPC1.  Many customers use 2+ AZs.  This is so that the demo can match the customer environment.


Execute the Terraform:

```
terraform init
terraform plan --var-file=var.tfvars
terraform apply --var-file=var.tfvars
```

The result of the Terraform deploy will deliver the following outputs:

* `test_machine_ui`: Web front-end for the test machines.  This is a single Load Balancer with multiple listeners.  Port 80 maps to AZ1.  Port 81 maps to AZ2.  Port 82 maps to AZ3, etc.
* `guacamole_login_url`: Login URL for Guacamole.  Includes authentication.  Copy and paste this in a browser to access the RDP session.
* `guacamole_fqdn`: FQDN for the Guacamole public-facing remote access server. Used by the Guacamole configuration Terraform config.
* `guacamole_password`: Guacamole password. Used by the Guacamole configuration Terraform config.
* `guacamole_username`: Guacamole username. Used by the Guacamole configuration Terraform config.
* `vpc1_windows_instances`: Information on the Windows server. Used by the Guacamole configuration Terraform config.

# Demo Flow

## 3 Clicks to Distributed Cloud Firewall
In this demo we will enable Distributed Cloud Firewall for Egress in 3 clicks.  This assumes the gateways are pre-staged in the VPCs.

* **Click 1:** Enable SNAT on the VPC Gateway Group
* **Click 2:** Configure FQDN Policy Group
* **Click 3:** Enable FQDN Filtering on the VPC Gateway Group

To demonstrate Distributed Cloud Firewall for Egress, you must be on controller version 7.1 and CoPilot version 3.12.

Make sure that ThreatGuard is enabled as this is not currently supported via Terraform.  Optionally configure CoPilot alerting.

1. Start with CoPilot.  
2. Click on Topology -> Highlight Topology and the VPCs.  Show the workloads that are deployed.
3. Click on Gateways -> Spokes -> vpc1 -> Cloud Routes:  Show that the route tables are pointing to NAT gateways in the private subnets across each AZ.  Optionally validate this in the AWS portal.
4. Open the Test Machine UI to show the different kind of traffic flows.  Everything should be green.
5. Swap out the NAT gateways by returning to CoPilot and clicking on the `Settings` tab.  Expand `Network Address Translation`.  Toggle the `Source NAT` switch and click Save.
6. Return to the Cloud Routes tab and refresh the table.  Show that Aviatrix has automatically swapped the default route to point to the gateway in that subnets local AZ.  If deployed with AWS TGW, note that the private route still points to TGW.
7. Return to the Test Machine UI.  Show that none of the traffic is affected.  Optionally highlight latency for the responses to show that there is no latency impact to inserting Avatrix Egress gateways.
8. Wait for a minute for Threatguard to kick in.  We should see that the "Tor" connection is now blocked.  Note: This could take up to 20 seconds as the request needs to timeout before it's.
9. Demo Threatguard.  Show that we can identify details of the Threat that has been blocked.  Highlight Threat Prevention as one of the default values of the solution even if you don't initially do FQDN filtering.
10. Demo FlowIQ.  Show holistic visibility into Egress traffic.  Highlight that this can be used for Forensics, troubleshooting, or understanding how to reduce Egress charges.
11. Demo FQDN/Egress Filtering by filtering out one of the FQDNs.
12. Return to the Test Machine UI.  Show that one the target FQDN is no longer accessible.