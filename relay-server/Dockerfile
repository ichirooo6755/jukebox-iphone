FROM python:3.12-slim

WORKDIR /app

COPY relay-server/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY relay-server/main.py .
COPY web /web

ENV WEB_ROOT=/web
EXPOSE 8780

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8780"]
