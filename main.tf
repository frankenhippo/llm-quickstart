terraform {
  required_providers {
    google = {
      source = "hashicorp/google",
      version = "6.10.0"
    }
  }
  backend "gcs" {
    bucket = ""
    prefix = ""
  }
}

provider "google" {
  project                = var.builder_project_id
  user_project_override  = true
  billing_project        = var.builder_project_id
}

locals {
  repository_id          = format("%s-repo", var.data_store_name)
  repository_descrition  = format("Repository for Gemini search app grounded in %s", var.data_store_name)
}

data "google_project" "builder_project" {project_id = var.builder_project_id}

resource "google_project_service" "builder_required_apis" {
  for_each               = toset(var.builder_apis)
  project                = var.builder_project_id
  service                = each.value
  disable_on_destroy     = false
}

resource "google_artifact_registry_repository" "my-repo" {
  location               = var.region
  repository_id          = local.repository_id
  description            = local.repository_description
  format                 = "DOCKER"
  docker_config {
    immutable_tags       = false
  }
  depends_on             = [google_project_service.builder_required_apis]
}

locals {
  landing_bucket         = format("%s-%s-bucket", var.landing_project_id, var.data_store_name)
}

data "google_project" "landing_project" {project_id = var.landing_project_id}

resource "google_storage_bucket" "landing-bucket" {
  name                   = local.landing_bucket
  location               = var.region
  project                = var.landing_project_id
  force_destroy          = true
}

locals {
  python                 = (substr(pathexpand("~"), 0, 1) == "/") ? "python3" : "python.exe"
  data_store_id          = format("%s-id", var.data_store_name)
  app_name               = format("%s-search-app", var.data_store_name)
  app_id                 = format("%s-search-app-id", var.data_store_name)
  documents_uri          = format("gs://%s/*.pdf", local.landing_bucket)
}

data "google_project" "application_project" {project_id = var.application_project_id}

resource "google_project_service" "application_required_apis" {
  for_each               = toset(var.application_apis)
  project                = var.application_project_id
  service                = each.value
  disable_on_destroy     = false
}

resource "google_discovery_engine_datastore" "demo-ds" {
  location                    = "global"
  data_store_id               = local.data_store_id
  display_name                = local.data_store_name
  industry_vertical           = "GENERIC"
  content_config              = "CONTENT_REQUIRED"
  solution_types              = ["SOLUTION_TYPE_SEARCH"]
  create_advanced_site_search = false
  project                     = var.application_project_id
  depends_on                  = [ google_project_service.application_required_apis ]
}

resource "google_discovery_engine_search_engine" "demo-engine" {
  engine_id                   = local.app_id
  collection_id               = "default_collection"
  location                    = google_discovery_engine_data_store.demo-ds.location
  display_name                = local.app_name
  industry_vertical           = "GENERIC"
  data_store_ids              = [google_discovery_engine_data_store.demo-ds.data_store_id]
  common_config {
    comapny_name              = var.company_name
  }
  search_engine_config {
    search_add_ons              = ["SEARCH_ADD_ON_LLM"]
    search_tier                 = "SEARCH_TIER_ENTERPRISE"
  }
  project                       = var.application_project_id
}

resource "google_project_iam_member" "storage_viewer_binding" {
  project                       = var.landing_project_id
  role                          = "roles/storage.objectViewer"
  member                        = format("serviceAccount:service-%s@gcp-sa-discoveryengine.iam.gserviceaccount.com", data.google_project.application_project.number)
  depends_on                    = [google_project_service.application_required_apis]
}

locals {
  loader_service                = format("%s-doc_loader", var.data_store_name)
  loader_sa                     = format("%s-sa", var.data_store_name)
  loader_schedule               = format("%s-load-schedule", var.data_store_name)
  repository_path               = format("%s-docker.pkg.dev/%s/%s", var.region, var.builder_project_id, local.repository_id)
  build_script                  = file("${path.module}/scripts/push-image.sh")
  loader_dkf_path               = "'${path.module}/loader-app/Dockerfile'")
  loader_pyfile                 = file("${path.module}/loader-app/app.py")
}

data "template_file" "push_loader_image_command" {
  template                      = "${local.build_script}"
  vars = {
    build_folder                = "loader-app"
    project_id                  = var.builder_project_id
    repo_path                   = local.repository_path
    image_name                  = local.loader_service
  }
}

resource "null_resource" "push_loader_image" {
  triggers = {
    repo_path                   = "${local.repository_path}"
    image_name                  = "${local.loader_service}"
    script_sha                  = "${sha_256(local.build_script)}"
    pyfile_sha                  = "${sha_256(local.loader_pyfile)}"
  }
  provisioner "local-exec" {
    command                     = "${data.template_file.push_loader_image_command.rendered}"
    interpreter                 = ["/bin/bash", "-c"]
  }
}

resource "google_project_iam_member" "artifact_viewer_binding" {
  project                       = var.builder_project_id
  role                          = "roles/artifactregistry.reader"
  member                        = format("serviceAccount:service-%s@serverless-robot-prod.iam.gserviceaccount.com", data.google_project.application_project.number)
  depends_on                    = [google_project_service.application_required_apis, google_project_service.application_required_apis]
}  

resource "google_cloud_run_v2_service" "loader-service" {
  name                          = local.loader_service
  project                       = var.application_project_id
  location                      = var.region
  deletion_protection           = false

  template {
    containers {
      image                     = "${local.repository_path}/${local.loader_service}:latest"
      env {
        name                    = "PROJECT_ID"
        value                   = var.application_project_id
      }
      env {
        name                    = "DATA_STORE_ID"
        value                   = local.data_store_id
      }
      env {
        name                    = "GCS_URI"
        value                   = local.documents_uri
      }
    }
  }
  depends_on                    = [ null_resource.push_loader_image, google_project_iam_member.artifact_viewer_binding ]
}

resource "google_service_account" "loader-sa" {
  project                       = var.application_project_id
  account_id                    = local.loader_sa
  description                   = "Cloud scheduler service account. Used to trigger scheduled Cloud Run jobs"
  display_name                  = local.loader_sa
}

resource "google_cloud_run_service_iam_member" "run-invoker" {
  project                       = var.application_project_id
  location                      = google_cloud_run_v2_service.loader-service.location
  service                       = google_cloud_run_v2_service.loader-service.name
  role                          = "roles/run.invoker"
  member                        = "serviceAccount:${google_service_account.loader-sa.email}"
  depends_on                    = [ google_project_service.application_required_apis ]
}

resource "google_cloud_scheduler_job" "loader-job" {
  name                          = local.loader_schedule
  project                       = var.application_project_id
  region                        = google_cloud_run_v2_service.loader-service.location
  description                   = "Invoke a data store import job"
  schedule                      = "0 0 * * *"
  time_zone                     = "America/New_York"
  attempt_deadline              = "320s"
  
  retry_config {
    retry_count                 = 1
  }

  http_target {
    http_method                 = "POST"
    uri                         = google_cloud_run_v2_service.loader-service.uri

    oidc_token {
      service_account_email     = google_service_account.loader-sa.email
    }
  }
}

locals {
  web_service                   = format("%s-web-app", var.data_store_name)
  web_sa                        = format("%s-sa", var.data_store_name)
  folder_path                   = "'${path.module}/web-app/Dockerfile'"
  web_pyfile                    = file("${path.module}/web-app/home.py")
}

data "google_project" "web_project" {project_id = var.web_project_id}

resource "google_project_service" "web_required_apis" {
  for_each               = toset(var.web_apis)
  project                = var.web_project_id
  service                = each.value
  disable_on_destroy     = false
}

data "template_file" "push_frontend_image_command" {
  template                      = "${local.build_script}"
  vars = {
    build_folder                = "web-app"
    project_id                  = var.builder_project_id
    repo_path                   = local.repository_path
    image_name                  = local.web_service
  }
}

resource "null_resource" "push_frontend_image" {
  triggers = {
    repo_path                   = "${local.repository_path}"
    image_name                  = "${local.web_service}"
    script_sha                  = "${sha_256(local.build_script)}"
    pyfile_sha                  = "${sha_256(local.web_pyfile)}"
  }
  provisioner "local-exec" {
    command                     = "${data.template_file.push_frontend_image_command.rendered}"
    interpreter                 = ["/bin/bash", "-c"]
  }
}

resource "google_project_iam_member" "web_artifact_viewer_binding" {
  project                       = var.builder_project_id
  role                          = "roles/artifactregistry.reader"
  member                        = format("serviceAccount:service-%s@serverless-robot-prod.iam.gserviceaccount.com", data.google_project.web_project.number)
  depends_on                    = [google_project_service.application_required_apis, google_project_service.application_required_apis]
} 

resource "google_cloud_run_v2_service" "web-service" {
  name                          = local.web_service
  project                       = var.web_project_id
  location                      = var.region
  deletion_protection           = false

  template {
    containers {
      image                     = "${local.repository_path}/${local.web_service}:latest"

      startup_probe {
        failure_threshold       = 5
        initial_delay_seconds   = 10
        timeout_seconds         = 3
        period_seconds          = 3

        http_get {
          path                  = "/"
          http_headers {
            name                = "Access-Control-Allow-Origin"
            value               = "*"
          }
        }
      }

      ports {
        container_port          = 8501
      }

      env {
        name                    = "PROJECT_ID"
        value                   = var.application_project_id
      }
      env {
        name                    = "REGION"
        value                   = var.region
      }
      env {
        name                    = "DATA_STORE_ID_ID"
        value                   = local.data_store_id
      }
      env {
        name                    = "PAGE_TITLE"
        value                   = var.page_title
      }
      env {
        name                    = "ST_TITLE"
        value                   = var.st_title
      }
    }
  }
  depends_on                    = [ null_resource.push_frontend_image, google_project_iam_member.web_artifact_viewer_binding ]
}

data "google_iam_policy" "noauth" {
  binding {
    roles                       = "roles/run.invoker"
    members                     = ["allUsers"]
  }
}

resource "google_cloud_run_service_iam_policy" "noauth" {
  location                      = google_cloud_run_v2_service.web-service.location
  project                       = google_cloud_run_v2_service.web-service.project
  service                       = google_cloud_run_v2_service.web-service.name
  policy_data                   = google_iam_policy.noauth.policy_data
}

resource "google_project_iam_member" "vertexai_viewer_binding" {
  project                       = var.application_project_id
  role                          = "roles/aiplatform.user"
  member                        = format("serviceAccount:%s-compute@developer.gserviceaccount.com", data.google_project.web_project.number)
  depends_on                    = [google_project_service.web_required_apis]
}  

resource "google_project_iam_member" "discoveryengine_viewer_binding" {
  project                       = var.application_project_id
  role                          = "roles/discoveryengine.viewer"
  member                        = format("serviceAccount:%s-compute@developer.gserviceaccount.com", data.google_project.web_project.number)
  depends_on                    = [google_project_service.web_required_apis]
}  
