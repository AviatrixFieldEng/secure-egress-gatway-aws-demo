output "guacamole_fqdn" {
  value = var.deploy_aws_workloads ? aws_eip.guacamole[0].public_dns : null
}

output "guacamole_login_url" {
  value = var.deploy_aws_workloads ? "https://${aws_eip.guacamole[0].public_dns}/#/index.html?username=guacadmin&password=${regex("'(\\w{12})'\\.", ssh_resource.guac_password[0].result)[0]}" : null
}

output "guacamole_username" {
  value = var.deploy_aws_workloads ? "guacadmin" : null
}

output "guacamole_password" {
  value = var.deploy_aws_workloads ? regex("'(\\w{12})'\\.", ssh_resource.guac_password[0].result)[0] : null
}

output "vpc1_windows_instances" {
  value = [for v in module.ec2_instance_windows : {
    ip       = v.private_ip,
    password = nonsensitive(rsadecrypt(v.password_data, module.key_pair[0].private_key_pem)),
    name = v.tags_all["Name"] }
  ]
}

output "test_machine_ui" {
  #value = var.deploy_aws_workloads ? ["http://${aws_lb.test-machine-ingress[0].dns_name}:80","http://${aws_lb.test-machine-ingress[0].dns_name}:81","http://${aws_lb.test-machine-ingress[0].dns_name}:82"] : null
  value = var.deploy_aws_workloads ? [for v in aws_lb_listener.test-machine-ingress : "http://${aws_lb.test-machine-ingress[0].dns_name}:${v.port}"] : null
}
