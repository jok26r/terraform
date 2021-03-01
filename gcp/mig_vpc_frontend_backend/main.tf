terraform {
  backend "gcs" {
    bucket = "terraform-backend-1111"
    prefix = "mig-vpc-fnd-bnd"
  }
}

provider "google" { // to be able to use this provider please set GOOGLE_APPLICATION_CREDENTIALS env var or if you have gcloud use the next command 'gcloud auth application-default login'
  project = var.project_id
  region  = "us-central1"
}

locals {
  app_names = toset(["frontend", "backend"])
}

#-----------------------------------------------------------------------------
# ENABLE PROJECT SERVICE APIs
#-----------------------------------------------------------------------------

resource "google_project_service" "cloudresourcemanager" {
  service            = "cloudresourcemanager.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "apis" {
  for_each           = toset(["iam.googleapis.com", "compute.googleapis.com"])
  service            = each.key
  disable_on_destroy = false
  depends_on         = [google_project_service.cloudresourcemanager]
}

#-----------------------------------------------------------------------------
# SERVICE ACCOUNTS
#-----------------------------------------------------------------------------

module "service_accounts" {
  for_each = local.app_names
  source   = "../modules/service_account"

  service_account_id = "${each.key}-service-account"
  depends_on         = [google_project_service.apis]
}

#-----------------------------------------------------------------------------
# VPC
#-----------------------------------------------------------------------------

resource "google_compute_network" "custom" {
  name                    = "mig-network"
  auto_create_subnetworks = false
  depends_on              = [google_project_service.apis]
}

resource "google_compute_subnetwork" "us-central1" {
  name          = "us-central1"
  ip_cidr_range = "10.0.0.0/24"
  region        = "us-central1"
  network       = google_compute_network.custom.id
}

resource "google_compute_firewall" "deny-egress-to-internet-for-backend" {
  name    = "deny-egress-to-internet-for-backend"
  network = google_compute_network.custom.name

  direction = "EGRESS"

  target_service_accounts = [module.service_accounts["backend"].service_account_email]
  destination_ranges      = ["0.0.0.0/0"]
  priority                = 65535

  deny {
    protocol = "all"
  }
}

resource "google_compute_firewall" "allow-ssh-to-frontend" {
  name    = "allow-ssh-to-frontend"
  network = google_compute_network.custom.name

  direction = "INGRESS"

  source_ranges           = ["0.0.0.0/0"]
  target_service_accounts = [module.service_accounts["frontend"].service_account_email]
  priority                = 100

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "allow-ssh-to-backend" {
  name    = "allow-ingress-ssh-to-backend"
  network = google_compute_network.custom.name

  direction = "INGRESS"

  source_service_accounts = values(module.service_accounts)[*].service_account_email
  target_service_accounts = [module.service_accounts["backend"].service_account_email]
  priority                = 101

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "allow-egress-ssh-to-backend-from-backend" {
  name    = "allow-egress-ssh-from-backend"
  network = google_compute_network.custom.name

  direction = "EGRESS"

  target_service_accounts = [module.service_accounts["backend"].service_account_email]
  destination_ranges      = [google_compute_subnetwork.us-central1.ip_cidr_range]
  priority                = 102

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

#-----------------------------------------------------------------------------
# INSTANCE TEMPLATES
#-----------------------------------------------------------------------------

data "google_compute_image" "debian" {
  family  = "debian-10"
  project = "debian-cloud"
}

resource "google_compute_instance_template" "apps" {
  for_each    = local.app_names
  name_prefix = "${each.key}-"
  description = "This template is used to create ${each.key} server instances."

  labels = {
    type = each.key
  }

  instance_description = each.key
  machine_type         = var.machine_type
  can_ip_forward       = false

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }

  // Create a new boot disk from an image
  disk {
    source_image = data.google_compute_image.debian.id
    auto_delete  = true
    boot         = true
    disk_size_gb = 10
    disk_type    = "pd-standard"
  }

  network_interface {
    subnetwork = google_compute_subnetwork.us-central1.name
    dynamic "access_config" {
      for_each = each.key == "frontend" ? [1] : []
      content {}
    }
  }

  service_account {
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    email  = module.service_accounts[each.key].service_account_email
    scopes = ["cloud-platform"]
  }
}

#-----------------------------------------------------------------------------
# MANAGED INSTANCE GROUPS
#-----------------------------------------------------------------------------

resource "google_compute_region_instance_group_manager" "igms" {
  for_each = local.app_names
  name     = "${each.key}-igm"

  base_instance_name        = each.key
  region                    = "us-central1"
  distribution_policy_zones = ["us-central1-a", "us-central1-f"]

  version {
    instance_template = google_compute_instance_template.apps[each.key].id
    name              = "main"
  }

  update_policy {
    type                         = "PROACTIVE"
    instance_redistribution_type = "PROACTIVE"
    minimal_action               = "REPLACE"
    max_surge_fixed              = 2
    max_unavailable_fixed        = 0
    min_ready_sec                = 50
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_region_autoscaler" "scalers" {
  for_each = local.app_names
  name     = "${each.key}-region-autoscaler"
  region   = "us-central1"
  target   = google_compute_region_instance_group_manager.igms[each.key].id

  autoscaling_policy {
    max_replicas    = 4
    min_replicas    = each.key == "frontend" ? 3 : 2
    cooldown_period = 60


    cpu_utilization {
      target = 0.6
    }
  }
}
