provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}


# -----------------------------------------------------------------------------
#  Create GCP Project
# -----------------------------------------------------------------------------

resource "google_project" "playground" {
  name            = var.project_id
  project_id      = var.project_id
  billing_account = var.billing_account
}

# Enable Dataform API
resource "google_project_service" "dataform_api" {
  project = google_project.playground.project_id
  service = "dataform.googleapis.com"
  disable_on_destroy = false
  depends_on = [google_project.playground]
}

# Enable BigQuery API
resource "google_project_service" "bigquery_api" {
  project = google_project.playground.project_id
  service = "bigquery.googleapis.com"
  disable_on_destroy = false
  depends_on = [google_project.playground]
}


# -----------------------------------------------------------------------------
# Create Dataform Repository
# -----------------------------------------------------------------------------

resource "google_dataform_repository" "dataform_repo" {
  provider = google-beta
  project = google_project.playground.project_id
  region  = var.region
  name    = var.dataform_repo_name
  deletion_policy = "FORCE"
  depends_on = [google_project_service.dataform_api]

}


# -----------------------------------------------------------------------------
# 4. Grant Dataform Service Account Permissions
# -----------------------------------------------------------------------------

locals {
  dataform_service_account = "service-${google_project.playground.number}@gcp-sa-dataform.iam.gserviceaccount.com"
}

resource "google_project_iam_member" "ataform_bigquery_viewer" {
  project = google_project.playground.project_id
  role    = "roles/bigquery.dataViewer"
  member  = "serviceAccount:${local.dataform_service_account}"
  depends_on = [google_dataform_repository.dataform_repo] # Depend on repo existence
}

resource "google_project_iam_member" "dataform_bigquery_editor" {
  project = google_project.playground.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${local.dataform_service_account}"
  depends_on = [google_dataform_repository.dataform_repo]
}

resource "google_project_iam_member" "dataform_bigquery_jobuser" {
  project = google_project.playground.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${local.dataform_service_account}"
  depends_on = [google_dataform_repository.dataform_repo]
}

resource "google_project_iam_member" "dataform_editor" {
  project = google_project.playground.project_id
  role    = "roles/dataform.editor"
  member  = "serviceAccount:${local.dataform_service_account}"
  depends_on = [google_dataform_repository.dataform_repo]
}

resource "google_project_iam_binding" "storage_viewer" {
  project = var.project_id
  role    = "roles/storage.objectUser"
  members = [
    "serviceAccount:${local.dataform_service_account}",
  ]
  depends_on = [google_storage_bucket.source_data_storage]

}

# -----------------------------------------------------------------------------
# Create Bucket and load source data
# -----------------------------------------------------------------------------
resource "google_storage_bucket" "source_data_storage" {
  name          = "raw-data-storage"
  location      = var.region
  force_destroy = true
}

resource "google_storage_bucket_object" "inputdata_revenue" {
  name   = "source_data/revenue.csv"
  bucket = google_storage_bucket.source_data_storage.name
  source = "source_data/revenue.csv"
}

resource "google_storage_bucket_object" "inputdata_customers" {
  name   = "source_data/customers.csv"
  bucket = google_storage_bucket.source_data_storage.name
  source = "source_data/customers.csv"
}

# -----------------------------------------------------------------------------
# Create BigQuery Datasets
# -----------------------------------------------------------------------------

resource "google_bigquery_dataset" "raw" {
  project    = google_project.playground.project_id
  dataset_id = var.bq_raw_dataset_id
  location   = var.region
  friendly_name = "Raw Data"
  description = "Dataset for raw or source data"
  delete_contents_on_destroy = true
  depends_on = [google_project_service.bigquery_api]
}

# -----------------------------------------------------------------------------
# Create L0 External Tables
# -----------------------------------------------------------------------------
resource "google_bigquery_table" "L0_customers" {
  dataset_id          = google_bigquery_dataset.raw.dataset_id
  table_id            = "L0_CUSTOMERS"
  deletion_protection = false

  external_data_configuration {
    autodetect    = true
    source_format = "CSV"

    csv_options {
      quote = ""
      skip_leading_rows = 1
    }

    source_uris = [
      "gs://raw-data-storage/source_data/customers.csv",
    ]
  }
}

resource "google_bigquery_table" "L0_revenue" {
  dataset_id          = google_bigquery_dataset.raw.dataset_id
  table_id            = "L0_REVENUE"
  deletion_protection = false

  external_data_configuration {
    autodetect    = true
    source_format = "CSV"

    csv_options {
      quote = ""
      skip_leading_rows = 1
    }

    source_uris = [
      "gs://raw-data-storage/source_data/revenue.csv",
    ]
  }
}