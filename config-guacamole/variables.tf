variable "guacamole_fqdn" {

}

variable "guacamole_username" {

}

variable "guacamole_password" {

}

variable "vpc1_windows_instances" {
    type = set(object({
        ip = string
        name = string
        password = string
    }))
}
