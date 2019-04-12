# DNS managed zone
resource "google_dns_managed_zone" "managed" {
  name     = "${var.project["dns_zone_id"]}"
  dns_name = "${var.project["dns_zone_fqdn"]}"
}

module "app" {
  count     = 2
  host_type = "app"
  source    = "modules/cluster"

  machine_type = "n1-standard-4"
}

module "consul" {
  count     = 5
  host_type = "consul"
  source    = "modules/cluster"
}

module "lb" {
  count     = 2
  host_type = "lb"
  source    = "modules/cluster"

  machine_type  = "n1-standard-1"
  access_config = [{}]
}

data "google_compute_instance" "lb_hosts" {
  count      = 2
  depends_on = ["module.lb"]
  name       = "lb-${count.index}"
  zone       = "${var.project["region"]}-${var.project["zone"]}"
}

# Multi-A DNS for LB hosts with external IPs
resource "google_dns_record_set" "dns-lb" {
  managed_zone = "${var.project["dns_zone_id"]}"
  name         = "draniki-lb.${var.project["dns_zone_fqdn"]}"
  type         = "A"
  ttl          = 60

  rrdatas = [
    "${data.google_compute_instance.lb_hosts.0.network_interface.0.access_config.0.nat_ip}",
    "${data.google_compute_instance.lb_hosts.1.network_interface.0.access_config.0.nat_ip}",
  ]
}
