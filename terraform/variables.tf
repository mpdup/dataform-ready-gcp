# variables.tf

variable "billing_account" {
  description = "Your GCP billing account ID"
  type        = string
}

variable "project_id" {
  description = "The ID for the new GCP project. Must be globally unique."
  type        = string
}

variable "region" {
  description = "The GCP region for Dataform and BigQuery resources."
  type        = string
  default     = "europe-west4"
}

variable "bq_raw_dataset_id" {
  description = "ID for the BigQuery dataset storing raw data."
  type        = string
  default     = "L0_raw_data"
}

variable "dataform_repo_name" {
  description = "Name of your Dataform repository."
  type        = string
  default     = "dataform-sandbox-repository"
}