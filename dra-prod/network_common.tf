resource "google_compute_address" "gateway_static_ip_1" {
  name = "gateway-static-ip-1"
}

resource "google_compute_address" "gateway_static_ip_2" {
  name = "gateway-static-ip-2"
}

resource "google_compute_router" "router" {
  name    = "router"
  region  = "${var.project["region"]}"
  network = "https://www.googleapis.com/compute/v1/projects/${var.project["id"]}/global/networks/default"

  bgp {
    asn = 64514
  }
}

resource "google_compute_router_nat" "simple-nat" {
  name                               = "nat-1"
  router                             = "${google_compute_router.router.name}"
  region                             = "${var.project["region"]}"
  nat_ip_allocate_option             = "MANUAL_ONLY"
  nat_ips                            = ["${google_compute_address.gateway_static_ip_1.self_link}"]
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

resource "google_compute_global_address" "private_ip_address" {
  provider      = "google-beta"
  name          = "private-ip-address"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = "https://www.googleapis.com/compute/v1/projects/${var.project["id"]}/global/networks/default"
}

resource "google_compute_network_peering" "cloudsql-postgres-googleapis-com" {
  name         = "cloudsql-postgres-googleapis-com"
  network      = "https://www.googleapis.com/compute/v1/projects/${var.project["id"]}/global/networks/default"
  peer_network = "https://www.googleapis.com/compute/v1/projects/speckle-umbrella-pg-10/global/networks/cloud-sql-network-559872861378-e9685cc4efde17c8"
}

resource "google_service_networking_connection" "private_vpc_connection" {
  count                   = 0
  provider                = "google-beta"
  network                 = "https://www.googleapis.com/compute/v1/projects/${var.project["id"]}/global/networks/default"
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = ["${google_compute_global_address.private_ip_address.name}"]
}
