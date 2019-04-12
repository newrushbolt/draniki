terraform {
  backend "gcs" {
    prefix = ""
  }
}

provider "google" {
  project = "${var.project["id"]}"
  region  = "${var.project["region"]}"

  version = "> 2.1.0"

  credentials = "${file("~/.secrets/${var.project["id"]}-tf.json")}"
}

provider "google-beta" {
  project = "${var.project["id"]}"
  region  = "${var.project["region"]}"

  version = "> 2.1.0"

  credentials = "${file("~/.secrets/${var.project["id"]}-tf.json")}"
}
