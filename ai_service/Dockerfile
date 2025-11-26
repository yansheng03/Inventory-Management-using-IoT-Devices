FROM python:3.10-slim

WORKDIR /app

# Simple install - No system libs needed for Gemini
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

ENV PORT 8080
EXPOSE 8080

CMD ["gunicorn", "-w", "1", "-k", "uvicorn.workers.UvicornWorker", "main:app", "--bind", "0.0.0.0:8080", "--timeout", "120"]