# Imagen genérica para desplegar las funciones HTTP de la carpeta simple/* en Cloud Run/Cloud Functions (2nd gen).
#
# Ejemplos:
#   docker build -f simple/Dockerfile --build-arg SIMPLE_FUNCTION=bugsnag-ingest-function -t bugsnag-ingest-function .
#   docker build -f simple/Dockerfile --build-arg SIMPLE_FUNCTION=testrail-ingest-function -t testrail-ingest-function .
#   docker build -f simple/Dockerfile --build-arg SIMPLE_FUNCTION=jira-ingest-function -t jira-ingest-function .
#   docker build -f simple/Dockerfile --build-arg SIMPLE_FUNCTION=gamebench-ingest-function -t gamebench-ingest-function .

FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    FUNCTION_TARGET=hello_http \
    PORT=8080

WORKDIR /opt/build

COPY simple /opt/simple

# Nombre esperado de servicio/función para mapearlo a la subcarpeta correcta dentro de simple/.
ARG SIMPLE_FUNCTION=bugsnag-ingest-function

RUN case "${SIMPLE_FUNCTION}" in \
      bugsnag-ingest-function) echo "bugsnag" > /tmp/simple_function_dir ;; \
      testrail-ingest-function) echo "testrail" > /tmp/simple_function_dir ;; \
      jira-ingest-function) echo "jira" > /tmp/simple_function_dir ;; \
      gamebench-ingest-function) echo "gamebench" > /tmp/simple_function_dir ;; \
      *) echo "SIMPLE_FUNCTION inválida: ${SIMPLE_FUNCTION}" >&2; exit 1 ;; \
    esac

RUN pip install --no-cache-dir -r "/opt/simple/$(cat /tmp/simple_function_dir)/requirements.txt"

WORKDIR /app
RUN dir="$(cat /tmp/simple_function_dir)" && cp "/opt/simple/${dir}"/*.py /app/

CMD ["sh", "-c", "functions-framework --target=${FUNCTION_TARGET} --source=main.py --port=${PORT}"]
