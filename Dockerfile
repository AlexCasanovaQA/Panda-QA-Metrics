# Generic Cloud Run container for any of the ingest-*.py entrypoints.
# Build with: docker build --build-arg SOURCE_FILE=ingest-jira.py -t your-image .
FROM python:3.11-slim

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

ARG SOURCE_FILE=ingest-jira.py
ENV FUNCTION_SOURCE=${SOURCE_FILE}
ENV FUNCTION_TARGET=hello_http
ENV PORT=8080

CMD ["sh", "-c", "functions-framework --target=${FUNCTION_TARGET} --source=${FUNCTION_SOURCE} --port=${PORT}"]
