cd ${build_folder}
gcloud --project=${project_id} builds submit --tag ${repo_path}/${image_name}:latest
