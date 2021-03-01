resource "google_service_account" "this" {
  account_id   = var.service_account_id
  display_name = "Custom created ${var.service_account_id} service account"
}

# resource "google_project_iam_binding" "this" {
#   for_each = toset(var.roles_for_bindings)
#   role     = each.key

#   members = [
#     "serviceAccount:${google_service_account.this.email}"
#   ]
# }

resource "google_project_iam_member" "this" {
  for_each = toset(var.roles_for_bindings)
  role     = each.key
  member   = "serviceAccount:${google_service_account.this.email}"
}
