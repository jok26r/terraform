terraform {
  backend "gcs" {
    bucket = "terraform-backend-1111"
    prefix = "gce"
  }
}

provider "google" { // to be able to use this provider please set GOOGLE_APPLICATION_CREDENTIALS env var or if you have gcloud use the next command 'gcloud auth application-default login'
  project = var.project_id
  region  = "us-central1"
}

#--------------------------------------------------------------
# All additional stuff that is needed to create a GCE instance
#--------------------------------------------------------------

data "google_compute_image" "debian" {
  family  = "debian-10"
  project = "debian-cloud"
}

resource "random_string" "bucket_id" {
  length  = 8
  lower   = true
  number  = true
  special = false
  upper   = false
}

resource "google_storage_bucket" "logs" {
  name          = "bucket-logs-${random_string.bucket_id.result}"
  force_destroy = true
  location      = "US-CENTRAL1"
}

resource "google_project_service" "cloudresourcemanager" {
  service = "cloudresourcemanager.googleapis.com"
}

resource "google_project_service" "apis" {
  for_each   = toset(["iam.googleapis.com", "compute.googleapis.com"])
  service    = each.key
  depends_on = [google_project_service.cloudresourcemanager]
}

#----------------------------------------------------------------------------------------------------
# SERVICE ACCOUNT
# We can manage which service account we want to use the default compute engine or
# a custom one. To use a custom just set variable use_default_compute_engine_service_account to false
#----------------------------------------------------------------------------------------------------

data "google_compute_default_service_account" "default" {
  count      = var.use_default_compute_engine_service_account == true ? 1 : 0
  depends_on = [google_project_service.apis]
}

module "service_account" {
  count  = var.use_default_compute_engine_service_account == false ? 1 : 0
  source = "../modules/service_account"

  service_account_id = "gce-service-account"
  depends_on         = [google_project_service.apis]
}

resource "google_storage_bucket_iam_member" "member" {
  count  = var.use_default_compute_engine_service_account == false ? 1 : 0
  bucket = google_storage_bucket.logs.name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${module.service_account[0].service_account_email}"
}

#--------------------------------------------------------------------------
# CREATION OF GCE INSTANCE
#--------------------------------------------------------------------------

resource "google_compute_instance" "default" {
  name         = "gce-terraform-instance"
  machine_type = var.machine_type
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = data.google_compute_image.debian.self_link
    }
  }

  network_interface {
    network = "default"
    access_config {
      // Ephemeral IP
    }
  }

  metadata = {
    "logs-bucket" = google_storage_bucket.logs.url
  }

  metadata_startup_script = file("external/startup-script.sh")

  service_account {
    email  = var.use_default_compute_engine_service_account == true ? data.google_compute_default_service_account.default[0].email : module.service_account[0].service_account_email
    scopes = var.use_default_compute_engine_service_account == true ? ["storage-full", "logging-write", "monitoring-write"] : ["cloud-platform"]
  }

  depends_on = [google_project_service.apis]

}
