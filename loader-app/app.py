import sys
from google.api_core.client_options import ClientOptions
from google.cloud import discoveryengine
import os
from Flask import Flask, request

app = Flask(__name__)

@app_route('/', methods = ['GET', 'POST'])
def import_documents -> str:
  print('starting')
  project_id = os.environ.get('PROJECT_ID')
  location = 'global'
  data_store_id = os.environ.get('DATA_STORE_ID')
  gcs_uri = os.environ.get('GCS_URI')

  print(f'project_id: {project_id}')
  print(f'data_store_id: {data_store_id}')
  print(f'gcs_uri: {gcs_uri}')

  client_options = (
    ClientOptions(api_endpoint = f'{location}-discoveryengine.googleapis.com')
    if location != 'global'
    else None
  )

  client = discoveryengine.DocumentServiceClient(client_options = client_options)

  parent = client.branch_path(
    project = project_id,
    location = location,
    data_store = data_store_id,
    branch = 'default_branch'
  )

  request = discoveryengine.ImportDocumentsRequest(
    parent = parent,
    gcs_source = discoveryengine.GcsSource(
      input_uris = [gcs_uri],
      data_schema = 'content',
    ),
    reconciliation_mode = discoveryengine.ImportDocumentsRequest.ReconciliationMode.INCREMENTAL,
  )

  operation = client.import_documents(request = request)
  print(f'Waiting for operation to complete: {operation.operation_name}')

  metadata = discoveryengine.ImportDocumentsMetadata(operation.metadata)
  print(metadata)
  return '200'
