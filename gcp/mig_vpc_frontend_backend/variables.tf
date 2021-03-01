variable "project_id" {
  type    = string
  default = "terraform-tests-1111"
}

variable "machine_type" {
  type        = string
  description = "Type of machine to use with deployment. All available machine types can be found here https://cloud.google.com/compute/docs/machine-types#general_purpose"
  default     = "f1-micro"
}
