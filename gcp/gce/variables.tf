variable "project_id" {
  type    = string
  default = "terraform-tests-1111"
}

variable "use_default_compute_engine_service_account" {
  type        = bool
  description = "This variable acts as a switch which we can use to switch between default compute engine service accoutn or our own one"
  default     = true
}

variable "machine_type" {
  type        = string
  description = "Type of machine to use with deployment. All available machine types can be found here https://cloud.google.com/compute/docs/machine-types#general_purpose"
  default     = "f1-micro"
}
