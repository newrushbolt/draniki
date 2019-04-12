resource "google_compute_firewall" "tcp_input_rule" {
  name    = "tcp-input-rule"
  network = "https://www.googleapis.com/compute/v1/projects/${var.project["id"]}/global/networks/default"

  allow {
    protocol = "tcp"
    ports    = ["80", "8300", "8301", "8400", "9000-9999"]
  }

  source_ranges = ["${var.tunnel["remote_network"]}"]
}

resource "google_compute_firewall" "vpn_input_rule" {
  name    = "vpn-input-rule"
  network = "https://www.googleapis.com/compute/v1/projects/${var.project["id"]}/global/networks/default"

  allow {
    protocol = "udp"
    ports    = ["8300", "8301"]
  }

  source_ranges = ["${var.tunnel["remote_network"]}"]
}

resource "google_compute_vpn_gateway" "tunnel_gateway_1" {
  name    = "tunnel-gateway1"
  network = "https://www.googleapis.com/compute/v1/projects/${var.project["id"]}/global/networks/default"
}

resource "google_compute_forwarding_rule" "fr_esp" {
  name        = "fr-esp"
  ip_protocol = "ESP"
  ip_address  = "${google_compute_address.gateway_static_ip_2.address}"
  target      = "${google_compute_vpn_gateway.tunnel_gateway_1.self_link}"
}

resource "google_compute_forwarding_rule" "fr_udp500" {
  name        = "fr-udp500"
  ip_protocol = "UDP"
  port_range  = "500"
  ip_address  = "${google_compute_address.gateway_static_ip_2.address}"
  target      = "${google_compute_vpn_gateway.tunnel_gateway_1.self_link}"
}

resource "google_compute_forwarding_rule" "fr_udp4500" {
  name        = "fr-udp4500"
  ip_protocol = "UDP"
  port_range  = "4500"
  ip_address  = "${google_compute_address.gateway_static_ip_2.address}"
  target      = "${google_compute_vpn_gateway.tunnel_gateway_1.self_link}"
}

resource "google_compute_vpn_tunnel" "tunnel_1" {
  name               = "tunnel-1"
  peer_ip            = "${var.tunnel["remote_ip1"]}"
  shared_secret      = "${var.VPN_SECRET}"
  target_vpn_gateway = "${google_compute_vpn_gateway.tunnel_gateway_1.self_link}"

  depends_on = [
    "google_compute_forwarding_rule.fr_esp",
    "google_compute_forwarding_rule.fr_udp500",
    "google_compute_forwarding_rule.fr_udp4500",
  ]
}

resource "google_compute_vpn_tunnel" "tunnel_2" {
  name               = "tunnel-2"
  peer_ip            = "${var.tunnel["remote_ip2"]}"
  shared_secret      = "${var.VPN_SECRET}"
  target_vpn_gateway = "${google_compute_vpn_gateway.tunnel_gateway_1.self_link}"

  depends_on = [
    "google_compute_forwarding_rule.fr_esp",
    "google_compute_forwarding_rule.fr_udp500",
    "google_compute_forwarding_rule.fr_udp4500",
  ]
}

resource "google_compute_route" "tunnel_route_1" {
  name                = "tunnel-route-1"
  network             = "https://www.googleapis.com/compute/v1/projects/${var.project["id"]}/global/networks/default"
  dest_range          = "${var.tunnel["remote_network"]}"
  priority            = 1000
  next_hop_vpn_tunnel = "https://www.googleapis.com/compute/v1/projects/${var.project["id"]}/regions/${var.project["region"]}/vpnTunnels/tunnel-${var.tunnel["active_tunnel_id"]}"
}

resource "google_dns_record_set" "vpn-dns" {
  managed_zone = "${var.project["dns_zone_id"]}"
  name         = "vpn.${var.project["dns_zone_fqdn"]}"
  type         = "A"
  ttl          = 60

  rrdatas = [
    "${google_compute_address.gateway_static_ip_2.address}",
  ]
}
