variable "project" {
  type = "map"

  default = {
    "id"     = "dra-prod"
    "region" = "europe-west2"
    "zone"   = "a"

    "host_image" = "centos-cloud/centos-7"

    "dns_zone_fqdn" = "dra-prod.dra.com."
    "dns_zone_id"   = "dra-prod"
  }
}

variable "postgres" {
  type = "map"

  default = {
    "instance_index" = "9"
    "slave_count"    = 1
    "master_type"    = "db-custom-4-8192"
  }
}

variable "ssh_keys" {
  default = <<EOF
s.mihaylov:ssh-rsa AAAAB3N
l.mihaylov:ssh-rsa AAAAB3N
  EOF
}

variable "tunnel" {
  type = "map"

  default = {
    "active_tunnel_id" = "1"
    "remote_ip1"       = "114.21.108.120"
    "remote_ip2"       = "114.21.108.121"
    "remote_network"   = "192.168.255.0/24"
  }
}

variable "VPN_SECRET" {
  default = ""
}

# Fucked up magic, can be removed after release and migration to Terraform on HCL2
variable "ext_network" {
  default = [
    {
      network = "default"

      access_config = [
        {},
      ]
    },
  ]
}
