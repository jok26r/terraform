variable "workspace_to_environments" {
  default = {
    "dev"   = "dev",
    "stage" = "stage",
    "prod"  = "prod"
  }
}

variable "machine_type" {
  default = {
    "dev"  = "f1-micro",
    "prod" = "n1-standard-1"
  }
}

variable "autoscaler_replica_numbers" {
  default = {
    "dev" = {
      "min" = 2,
      "max" = 3
    },
    "stage" = {
      "min" = 3,
      "max" = 5
    },
    "prod" = {
      "min" = 5,
      "max" = 9
    }
  }
}
