resource "google_sql_database_instance" "draniki-postgres" {
  name   = "postgres-${var.postgres["instance_index"]}"
  region = "${var.project["region"]}"

  depends_on = [
    "google_service_networking_connection.private_vpc_connection",
  ]

  database_version = "POSTGRES_9_6"

  settings {
    activation_policy = "ALWAYS"

    availability_type = "REGIONAL"

    location_preference = {
      zone = "${var.project["region"]}-${var.project["zone"]}"
    }

    disk_autoresize = true
    disk_size       = 10
    disk_type       = "PD_SSD"
    tier            = "${var.postgres["master_type"]}"

    ip_configuration {
      ipv4_enabled    = "false"
      private_network = "https://www.googleapis.com/compute/v1/projects/${var.project["id"]}/global/networks/default"
    }

    maintenance_window {
      day          = 4
      hour         = 3
      update_track = "stable"
    }

    backup_configuration {
      enabled    = true
      start_time = "03:30"
    }
  }
}

resource "google_sql_database_instance" "draniki-postgres-slave" {
  name = "postgres-${var.postgres["instance_index"]}-slave"

  region = "${var.project["region"]}"

  count = "${var.postgres["slave_count"]}"

  depends_on = [
    "google_sql_database_instance.draniki-postgres",
    "google_service_networking_connection.private_vpc_connection",
  ]

  database_version = "POSTGRES_9_6"

  settings {
    activation_policy = "ALWAYS"

    location_preference = {
      zone = "${var.project["region"]}-${var.project["zone"]}"
    }

    tier = "${var.postgres["master_type"]}"

    ip_configuration {
      ipv4_enabled    = "false"
      private_network = "https://www.googleapis.com/compute/v1/projects/${var.project["id"]}/global/networks/default"
    }

    maintenance_window {
      day          = 3
      hour         = 3
      update_track = "stable"
    }
  }
}

resource "google_dns_record_set" "db-dns" {
  managed_zone = "${var.project["dns_zone_id"]}"
  name         = "postgres.${var.project["dns_zone_fqdn"]}"
  type         = "A"
  ttl          = 60

  rrdatas = [
    "${google_sql_database_instance.draniki-postgres.first_ip_address}",
  ]
}

resource "google_dns_record_set" "db-slave-dns" {
  managed_zone = "${var.project["dns_zone_id"]}"
  name         = "postgres-slave.${var.project["dns_zone_fqdn"]}"
  type         = "A"
  ttl          = 60

  rrdatas = [
    "${google_sql_database_instance.draniki-postgres-slave.*.first_ip_address}",
  ]
}
