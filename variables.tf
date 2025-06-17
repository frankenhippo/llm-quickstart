variable "region" {
  description  = "Default GCP region"
  type         = string
  default      = "europe-west2"
}

variable "builder_project_id" {
  description  = "GCP project ID for build activities & resources"
  type         = string
  default      = "builder-441017"
}

variable "landing_project_id" {
  description  = "GCP project ID for data staging area"
  type         = string
  default      = "landing-441017"
}

variable "application_project_id" {
  description  = "GCP project ID where loader app, data store & serch app will be deployed
  type         = string
  default      = "app-441017"
}

variable "web_project_id" {
  description  = "GCP project ID where web front-end will be deployed
  type         = string
  default      = "web-441017"
}

variable "data_store_name" {
  description  = "RAG dataa store name"
  type         = string
  default      = "cookbook-collection"
}

variable "page_title" {
  description  = "Title of front-end web page"
  type         = string
  default      = "Cookery Advice"
}

variable "st_title" {
  description  = "Subtitle of front-end web page"
  type         = string
  default      = "From the distant past"
}

variable "google_apis" {
  description  = ""
  type         = list(string)
  default      = [
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "logging.googleapis.com",
    "run.googleapis.com"
  ]
}
    
variable "builder_apis" {
  description  = ""
  type         = list(string)
  default      = [
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudresourcemanager.googleapis.com"
  ]
}

variable "application_apis" {
  description  = ""
  type         = list(string)
  default      = [
    "aiplatform.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "cloudscheduler.googleapis.com",
    "discoveryengine.googleapis.com",
    "iam.googleapis.com",
    "pubsub.googleapis.com",
    "run.googleapis.com"
  ]

  variable "web_apis" {
  description  = ""
  type         = list(string)
  default      = [
    "aiplatform.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "run.googleapis.com"
  ]
}
