variable "service_account_id" {
  type        = string
  description = "Service account id with length 6-30 characters"
  default     = "my-service-account"

  validation {
    condition     = length(var.service_account_id) >= 6 && length(var.service_account_id) <= 30 && can(regex("[a-z]([-a-z0-9]+[a-z0-9])", var.service_account_id))
    error_message = "Service account id must be 6-30 lowercase characters long, starts from letter and contains only letters, hyphens and digits."
  }
}

variable "roles_for_bindings" {
  type        = list(string)
  description = "Roles that will be assigned for a service account"
  default     = ["roles/monitoring.metricWriter", "roles/logging.logWriter"]
}
