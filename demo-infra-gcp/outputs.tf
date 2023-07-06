output "test_server_url" {
  value       = "http://${google_compute_global_address.lb_address.address}:80"
  description = "Public URL for the Test Server"
}