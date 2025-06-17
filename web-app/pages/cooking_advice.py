import streamlit as st
import os
import base64
import vertexai
from vertexai.preview.generative_models import GenerativeModel, SafetySetting, Part, Tool, grounding
import logging

project_id = os.environ.get('PROJECT_ID')
region = os.environ.get('REGION')
data_store_id = os.environ.get('DATA_STORE_ID')
page_title = os.environ.get('PAGE_TITLE')
st_title = os.environ.get('ST_TITLE')

data_store_path = f'projects/{project_id}/locations/global/collections/default_collection/dataStores/{data_store_id}'

generation_config = {
  "max_output_tokens": 8192,
  "temperature":1,
  "top_p":0.95,
}

safety_settings = [
  SafetySetting(
    category = SafetySetting.HarmCategory.HARM_CATEGORY_HATE_SPEECH,
    threshold = SafetySetting.HarmBlockThreshold.BLOCK_MEDIUM_AND_ABOVE
  ),
    SafetySetting(
    category = SafetySetting.HarmCategory.HARM_CATEGORY_DANGEROUS_CONTENT,
    threshold = SafetySetting.HarmBlockThreshold.BLOCK_ONY_HIGH
  ),  
  SafetySetting(
    category = SafetySetting.HarmCategory.HARM_CATEGORY_SEXUALLY_EXPLICIT,
    threshold = SafetySetting.HarmBlockThreshold.BLOCK_MEDIUM_AND_ABOVE
  ),
  SafetySetting(
    category = SafetySetting.HarmCategory.HARM_CATEGORY_HARASSMENT,
    threshold = SafetySetting.HarmBlockThreshold.BLOCK_MEDIUM_AND_ABOVE
  ),
]

def start_chat_session():
  vertexai.init(project = project_id, location = region)
  tools = [
    Tool.from_retrieval(
      retrieval = grounding.Retrieval(
        source = grounding.VertexAISearch(datastore = data_store_path),
      )
    ),
  ]
  
  model = GenerativeModel(
    "gemini-1.5-flash-002",
    tools = tools,
    generation_config = generation_config,
    safety_settings = safety_settings,
  )

  chat = model.start_chat()
  logging.info('Chat session started')
  logging.info(str(model.__dict__))

start_chat_session()

if 'chat' not in st.session_state:
  st.session_state.chat = start_chat_session()
else:
  chat = st.session_state.chat

if 'history' not in st.session_state:
  st.session_state.history = st.session_state.chat.history

st.set_page_config(page_title = page_title)
st.title(st_title)

for message in st.session_state.history:
  with st.chat_message(message.role):
    st.markdown(message.parts[0].text)

if prompt := st.chat_input("How can I help you today?"):

  with st.chat_message('user'):
    st.markdown(prompt)

  print('Sending request')
  response = chat.send_message(prompt)
  print('Got response')

  with st.chat_message('assistant'):
    st.markdown(response.candidates[0].content.parts[0].text)
