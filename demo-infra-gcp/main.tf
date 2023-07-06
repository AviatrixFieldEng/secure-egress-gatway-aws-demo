terraform {
  required_providers {
        aviatrix = {
      source  = "AviatrixSystems/aviatrix"
      version = ">=3.0"
    }
    google = {
      source  = "hashicorp/google"
      version = ">= 3.5.0" # Update the version constraint as needed
    }
  }
}

provider "aviatrix" {
  skip_version_validation = true
}

provider "google" {
  project = var.gcp_project_name
  region  = var.gcp_region
  credentials = "/Users/christophermchenry/Documents/keys/cmchenry-01-fff1d9c4194e.json"
}

resource "google_compute_network" "vpc" {
  name = "secure-egress-vpc"
}

resource "google_compute_subnetwork" "subnet" {
  name          = "secure-egress-subnet"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.gcp_region
  network       = google_compute_network.vpc.self_link
}

resource "google_compute_router" "router" {
  name    = "vpc-router"
  network = google_compute_network.vpc.self_link
  region  = var.gcp_region
}

resource "google_compute_router_nat" "nat" {
  name   = "vpc-nat"
  region = google_compute_router.router.region
  router = google_compute_router.router.name

  nat_ip_allocate_option = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  # Uncomment and modify the following lines if you want to restrict
  # the NAT to specific subnetworks and their IP ranges.
  /*
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  subnetwork {
    name                    = google_compute_subnetwork.subnet.self_link
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
  */
}


resource "google_compute_firewall" "allow_http" {
  name    = "allow-http"
  network = google_compute_network.vpc.self_link

  allow {
    protocol = "tcp"
    ports    = ["80","22"]
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow_outbound" {
  name    = "allow-outbound"
  network = google_compute_network.vpc.self_link

  allow {
    protocol = "all"
  }

  source_ranges = ["10.0.0.0/16"] # Replace with your subnet's CIDR range
  direction = "EGRESS"
}

resource "google_compute_instance" "apache_web_server" {
  name         = "apache-web-server"
  machine_type = "e2-small"
  zone         = "${var.gcp_region}-b"

  boot_disk {
    initialize_params {
      image = "projects/debian-cloud/global/images/family/debian-10"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.subnet.self_link
    # access_config {
    #   // Ephemeral IP
    # }
  }

  metadata_startup_script = file("${path.module}/vpc1_test_server.tftpl")
}

resource "google_compute_http_health_check" "default" {
  name = "default-http-health-check"
  request_path = "/"
  check_interval_sec = 30
  timeout_sec = 10
}

resource "google_compute_backend_service" "backend" {
  name        = "backend"
  port_name   = "http"
  protocol    = "HTTP"
  timeout_sec = 30

  health_checks = [google_compute_http_health_check.default.self_link]

  backend {
    group = google_compute_instance_group.web_instance_group.self_link
    balancing_mode = "UTILIZATION"
    capacity_scaler = 1
  }
}

resource "google_compute_instance_group" "web_instance_group" {
  name        = "web-instance-group"
  description = "Instance group for Apache web servers"
  zone        = "${var.gcp_region}-b"

  instances = [
    google_compute_instance.apache_web_server.self_link,
  ]

  named_port {
    name = "http"
    port = 80
  }
}

resource "google_compute_url_map" "url_map" {
  name            = "url-map"
  default_service = google_compute_backend_service.backend.self_link
}

resource "google_compute_target_http_proxy" "proxy" {
  name   = "proxy"
  url_map = google_compute_url_map.url_map.self_link
}

resource "google_compute_global_forwarding_rule" "forwarding_rule" {
  name       = "forwarding-rule"
  target     = google_compute_target_http_proxy.proxy.self_link
  port_range = "80"
  ip_address = google_compute_global_address.lb_address.address
}

resource "google_compute_global_address" "lb_address" {
  name = "lb-public-ip"
}

resource "aviatrix_spoke_gateway" "secure_egress" {
  cloud_type        = 4
  account_name      = var.aviatrix_gcp_account
  gw_name           = "avx-spoke-${var.gcp_region}"
  vpc_id            = "${google_compute_network.vpc.name}~-~${var.gcp_project_name}"
  vpc_reg           = "${var.gcp_region}-b"
  gw_size           = var.gateway_size
  subnet            = google_compute_subnetwork.subnet.ip_cidr_range
  # zone = "${var.gcp_region}-b"
  single_ip_snat    = false
  manage_ha_gateway = false
}

resource "aviatrix_spoke_ha_gateway" "secure_egress" {
  primary_gw_name = aviatrix_spoke_gateway.secure_egress.id
  zone            = "${var.gcp_region}-b"
  gw_size         = var.gateway_size
  subnet          = google_compute_subnetwork.subnet.ip_cidr_range
}