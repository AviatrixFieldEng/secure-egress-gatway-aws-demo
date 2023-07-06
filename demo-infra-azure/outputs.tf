output "test_server_url" {
  value       = "http://${azurerm_public_ip.lb.ip_address}:80"
  description = "Public URL for the Test Server"
}