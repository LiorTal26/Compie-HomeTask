# Base image

FROM python:3.13-slim-bookworm@sha256:e32be0e55814a08977501ca863271d9bd02443710db8f2afaf8372e2c4508530
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /app

# Dependencies

COPY requirements.txt ./
# The optional CA mount supports enterprise networks without storing certificates in the image.
RUN --mount=type=secret,id=pip_ca \
    if [ -f /run/secrets/pip_ca ]; then \
      pip install --no-cache-dir --cert /run/secrets/pip_ca -r requirements.txt; \
    else pip install --no-cache-dir -r requirements.txt; fi \
    && useradd --create-home --uid 10001 appuser

# Application files

COPY --chown=appuser:appuser app.py ./
COPY --chown=appuser:appuser templates/ ./templates/
COPY --chown=appuser:appuser static/ ./static/

# Release and runtime

ARG APP_VERSION=local
ENV APP_VERSION=$APP_VERSION
LABEL org.opencontainers.image.title="Compie Items Board" org.opencontainers.image.revision=$APP_VERSION

USER appuser
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/health', timeout=8)"

CMD ["gunicorn", \
     "--bind", "0.0.0.0:8080", \
     "--workers", "2", \
     "--threads", "2", \
     "--timeout", "30", \
     "--graceful-timeout", "20", \
     "--error-logfile", "-", \
     "app:create_app()"]
