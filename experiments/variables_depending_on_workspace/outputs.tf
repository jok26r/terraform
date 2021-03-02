output "vars" {
  value = {
    env          = local.environment,
    machine_type = local.machine_type,
    as_min_repls = local.autoscaler_min_replicas,
    as_max_repls = local.autoscaler_max_replicas
  }
}
