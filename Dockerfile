# syntax=docker/dockerfile:1.7

ARG PYTHON_IMAGE=python:3.13.5-slim-bookworm@sha256:4c2cf9917bd1cbacc5e9b07320025bdb7cdf2df7b0ceaccb55e9dd7e30987419
ARG UV_IMAGE=ghcr.io/astral-sh/uv:0.8.3@sha256:ef11ed817e6a5385c02cd49fdcc99c23d02426088252a8eace6b6e6a2a511f36

FROM ${UV_IMAGE} AS uv

FROM ${PYTHON_IMAGE} AS builder

COPY --from=uv /uv /uvx /usr/local/bin/

ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PYTHON_DOWNLOADS=never

WORKDIR /app

COPY pyproject.toml uv.lock README.md LICENSE ./
COPY src ./src

RUN --mount=type=cache,id=clintrace-uv,target=/root/.cache/uv \
    uv sync --frozen --no-dev --no-editable && \
    printf '%s\n' \
        'click==8.3.1 --hash=sha256:981153a64e25f12d547d3426c367a4857371575ee7ad18df2a6183ab0545b2a6' \
        'uvicorn==0.40.0 --hash=sha256:c6c8f55bc8bf13eb6fa9ff87ad62308bbbc33d0b67f84293151efe87e0d5f2ee' | \
        uv pip install --python /app/.venv/bin/python --no-deps \
            --no-config --require-hashes --requirement -

FROM ${PYTHON_IMAGE} AS runtime

ARG APP_UID=10001
ARG APP_GID=10001

ENV CLINTRACE_PROJECT_ROOT=/app \
    HOME=/home/clintrace \
    PATH=/app/.venv/bin:$PATH \
    PYTHONFAULTHANDLER=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

RUN groupadd --gid "${APP_GID}" clintrace && \
    useradd --uid "${APP_UID}" --gid "${APP_GID}" --create-home \
        --shell /usr/sbin/nologin clintrace && \
    apt-get update && \
    apt-get install --yes --no-install-recommends \
        poppler-utils \
        tesseract-ocr \
        tesseract-ocr-chi-sim \
        tesseract-ocr-eng && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=builder --chown=clintrace:clintrace /app/.venv /app/.venv
COPY --chown=clintrace:clintrace datasets ./datasets
COPY --chown=clintrace:clintrace knowledge ./knowledge
COPY --chown=clintrace:clintrace benchmark/baseline.json benchmark/cases.jsonl ./benchmark/
COPY --chown=clintrace:clintrace alembic.ini ./alembic.ini
COPY --chown=clintrace:clintrace migrations ./migrations
COPY deploy/bin/container-entrypoint.sh /usr/local/bin/clintrace-entrypoint

RUN chmod 0555 /usr/local/bin/clintrace-entrypoint

USER clintrace:clintrace

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health/ready', timeout=3).read()"]

ENTRYPOINT ["clintrace-entrypoint"]
CMD ["uvicorn", "clintrace.api:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1", "--timeout-keep-alive", "30", "--no-server-header"]
