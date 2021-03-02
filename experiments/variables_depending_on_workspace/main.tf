locals {
  environment             = lookup(var.workspace_to_environments, terraform.workspace, "dev")
  machine_type            = lookup(var.machine_type, terraform.workspace, lookup(var.machine_type, "dev", null))
  autoscaler_min_replicas = lookup(var.autoscaler_replica_numbers[local.environment], "min", null)
  autoscaler_max_replicas = lookup(var.autoscaler_replica_numbers[local.environment], "max", null)
}
