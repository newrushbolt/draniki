variable "host_type" {}
variable "count" {}

variable "ext_iface" {
  default = false
}

variable "machine_type" {
  default = "g1-small"
}

variable "access_config" {
  default = []
}

resource "google_compute_instance" "instance" {
  boot_disk {
    initialize_params {
      image = "${var.project["host_image"]}"
    }
  }

  allow_stopping_for_update = true

  count        = "${var.count}"
  machine_type = "${var.machine_type}"

  metadata {
    sshKeys = "${var.ssh_keys}"
  }

  description = "${var.host_type}-${count.index}.${var.project["dns_zone_fqdn"]}"

  labels = {
    consul_cluster_bootstrap_node = "${ (var.host_type == "consul" && count.index == 0) ? "true" : "false" }"
    group_name                    = "draniki_${var.host_type}"
  }

  metadata_startup_script = "curl https://gist.githubusercontent.com/newrushbolt/148b2d6609016597da57c27ac19863af/raw/cc2d334333111ed474ff63e6c6377ad72820a76c/install.sh -o post_install.sh&&sudo bash post_install.sh"
  name                    = "${var.host_type}-${count.index}"

  network_interface {
    network       = "default"
    access_config = "${var.access_config}"
  }

  zone = "${var.project["region"]}-${var.project["zone"]}"
}

resource "google_compute_instance_group" "instance-group" {
  name      = "draniki-${var.host_type}"
  zone      = "${var.project["region"]}-${var.project["zone"]}"
  instances = ["${google_compute_instance.instance.*.self_link}"]
}

# multi-A DNS for all the hosts in group, local IP
resource "google_dns_record_set" "dns-group-local" {
  managed_zone = "${var.project["dns_zone_id"]}"
  name         = "draniki-${var.host_type}.local.${var.project["dns_zone_fqdn"]}"
  type         = "A"
  ttl          = 60
  rrdatas      = ["${google_compute_instance.instance.*.network_interface.0.network_ip}"]
}

# DNS for internal IP
resource "google_dns_record_set" "dns-local" {
  count        = "${var.count}"
  managed_zone = "${var.project["dns_zone_id"]}"
  name         = "${var.host_type}-${count.index}.local.${var.project["dns_zone_fqdn"]}"
  type         = "A"
  ttl          = 60
  rrdatas      = ["${element(google_compute_instance.instance.*.network_interface.0.network_ip, count.index)}"]
}
