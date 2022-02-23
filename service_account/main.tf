resource "random_string" "cluster_service_account_tf_suffix" {
  upper   = false
  lower   = true
  special = false
  length  = 4
}

resource "google_service_account" "cluster_service_account_tf" {

  project      = var.project_id
  account_id   = "tf-gke-${substr(var.name, 0, min(15, length(var.name)))}-${random_string.cluster_service_account_tf_suffix.result}"
  display_name = "Terraform-managed service account for cluster ${var.name}"
}

resource "google_project_iam_member" "cluster_service_account_tf-log_writer" {

  project = google_service_account.cluster_service_account_tf.project
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.cluster_service_account_tf.email}"
}

resource "google_project_iam_member" "cluster_service_account_tf-metric_writer" {

  project = google_project_iam_member.cluster_service_account_tf-log_writer.project
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.cluster_service_account_tf.email}"
}

resource "google_project_iam_member" "cluster_service_account_tf-monitoring_viewer" {

  project = google_project_iam_member.cluster_service_account_tf-metric_writer.project
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.cluster_service_account_tf.email}"
}

resource "google_project_iam_member" "cluster_service_account_tf-resourceMetadata-writer" {

  project = google_project_iam_member.cluster_service_account_tf-monitoring_viewer.project
  role    = "roles/stackdriver.resourceMetadata.writer"
  member  = "serviceAccount:${google_service_account.cluster_service_account_tf.email}"
}

resource "google_project_iam_member" "cluster_service_account_tf-gcr" {

  project  = var.project_id
  role     = "roles/storage.objectViewer"
  member   = "serviceAccount:${google_service_account.cluster_service_account_tf.email}"
}

resource "google_project_iam_member" "cluster_service_account_tf-artifact-registry" {

  project  = var.project_id
  role     = "roles/artifactregistry.reader"
  member   = "serviceAccount:${google_service_account.cluster_service_account_tf.email}"
}