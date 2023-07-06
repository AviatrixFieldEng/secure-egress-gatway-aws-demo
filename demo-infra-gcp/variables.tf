variable "gcp_region" {
  description = "GCP Region"
  default     = "us-east-1"
}

variable "gcp_project_name" {
  description = "GCP Project Name"
  default     = "my-project-name"
}

variable "aviatrix_gcp_account" {
  description = "Aviatrix GCP Account"
  default     = "my-account"
}

variable "gateway_size" {
  description = "Aviatrix gateway size"
  default     = "n1-standard-2"
}

variable "gcp_credentials_path" {
    description = "Path to GCP Credentials File"
  default     = "../cred.json"
}