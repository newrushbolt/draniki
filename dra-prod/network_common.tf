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

# https://www.googleapis.com/compute/v1/projects/${var.project["id"]}/global/addresses/google-managed-services-default
resource "google_compute_global_address" "private_ip_address" {
  provider      = "google-beta"
  name          = "google-managed-services-default"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 20
  description   = "IP Range for peer networks."
  network       = "https://www.googleapis.com/compute/v1/projects/${var.project["id"]}/global/networks/default"
}

# https://www.googleapis.com/compute/v1/projects/${var.project["id"]}/global/networks/default:servicenetworking.googleapis.com
resource "google_service_networking_connection" "servicenetworking" {
  provider                = "google-beta"
  network                 = "https://www.googleapis.com/compute/v1/projects/${var.project["id"]}/global/networks/default"
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = ["${google_compute_global_address.private_ip_address.name}"]
}
