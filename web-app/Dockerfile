FROM python:3.11-slim-bookworm

EXPOSE 8501

WORKDIR /app

COPY requirements.txt ./

RUN pip install --no-cache-dir -r requirements.txt

COPY . .

CMD ['streamlit', 'run', 'home.py', '--server.enableCORS=false']
