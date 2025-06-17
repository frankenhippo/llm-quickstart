import streamlit as st
import os
from streamlit.components.v1 import html

project_id = os.environ.get('PROJECT_ID')
region = os.environ.get('REGION')
data_store_id = os.environ.get('DATA_STORE_ID')
data_store_path = f'projects/{project_id}/locations/global/collections/default_collection/dataStores/{data_store_id}'

st.title = os.environ.get('PAGE_TITLE')
