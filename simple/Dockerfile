# Imagen genérica para desplegar las funciones HTTP de la carpeta simple/* en Cloud Run/Cloud Functions (2nd gen).
#
# Ejemplos:
#   docker build -f simple/Dockerfile --build-arg SIMPLE_FUNCTION=bugsnag-ingest-function -t bugsnag-ingest-function .
#   docker build -f simple/Dockerfile --build-arg SIMPLE_FUNCTION=testrail-ingest-function -t testrail-ingest-function .
#   docker build -f simple/Dockerfile --build-arg SIMPLE_FUNCTION=jira-ingest-function -t jira-ingest-function .
#   docker build -f simple/Dockerfile --build-arg SIMPLE_FUNCTION=gamebench-ingest-function -t gamebench-ingest-function .
#
# Nota: Si SIMPLE_FUNCTION no se envía en build, el contenedor detecta la fuente en runtime
# con K_SERVICE (Cloud Run) y evita arrancar con el main equivocado.

FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    FUNCTION_TARGET=hello_http \
    PORT=8080

WORKDIR /opt/build

# Copiamos todo el contexto para soportar dos modos de build:
# 1) Contexto en raíz del repo (existe /opt/src/simple)
# 2) Contexto en carpeta simple/ (el código queda directo en /opt/src)
COPY . /opt/src

# Nombre esperado de servicio/función para mapearlo a la subcarpeta correcta dentro de simple/.
# Si se omite, runtime puede resolver desde K_SERVICE.
ARG SIMPLE_FUNCTION=

RUN if [ -d "/opt/src/simple" ]; then base="/opt/src/simple"; else base="/opt/src"; fi && \
    for dir in bugsnag jira testrail gamebench; do \
      pip install --no-cache-dir -r "${base}/${dir}/requirements.txt"; \
    done

WORKDIR /app
RUN if [ -d "/opt/src/simple" ]; then base="/opt/src/simple"; else base="/opt/src"; fi && \
    mkdir -p /app/bugsnag /app/jira /app/testrail /app/gamebench && \
    cp "${base}/bugsnag"/*.py /app/bugsnag/ && \
    cp "${base}/jira"/*.py /app/jira/ && \
    cp "${base}/testrail"/*.py /app/testrail/ && \
    cp "${base}/gamebench"/*.py /app/gamebench/

CMD ["sh", "-c", "set -e; \
  selected=''; \
  if [ -n \"${SIMPLE_FUNCTION}\" ]; then \
    case \"${SIMPLE_FUNCTION}\" in \
      bugsnag-ingest-function) selected='bugsnag' ;; \
      jira-ingest-function) selected='jira' ;; \
      testrail-ingest-function) selected='testrail' ;; \
      gamebench-ingest-function) selected='gamebench' ;; \
      *) echo \"SIMPLE_FUNCTION inválida: ${SIMPLE_FUNCTION}\" >&2; exit 1 ;; \
    esac; \
  elif [ -n \"${K_SERVICE}\" ]; then \
    case \"${K_SERVICE}\" in \
      bugsnag-ingest-function) selected='bugsnag' ;; \
      jira-ingest-function) selected='jira' ;; \
      testrail-ingest-function) selected='testrail' ;; \
      gamebench-ingest-function) selected='gamebench' ;; \
      *) echo \"No se pudo resolver source para K_SERVICE=${K_SERVICE}. Configura SIMPLE_FUNCTION.\" >&2; exit 1 ;; \
    esac; \
  else \
    echo \"Define SIMPLE_FUNCTION o despliega en Cloud Run con K_SERVICE.\" >&2; exit 1; \
  fi; \
  echo \"Using source: ${selected}/main.py\"; \
  functions-framework --target=${FUNCTION_TARGET} --source=${selected}/main.py --port=${PORT}"]
