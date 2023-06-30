resource "aviatrix_smart_group" "private_networks" {
  name = "Private-Networks"
  selector {
    match_expressions {
      cidr = "10.0.0.0/8"
    }
  }
}