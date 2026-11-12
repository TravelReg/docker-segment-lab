FROM python:3.15-slim@sha256:65a65fc7b30b06cb6df4930fd4650697cb23f4c2698ab81fc87e4b031bc36928

ARG APP_UID=10001

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PIP_NO_CACHE_DIR=1

WORKDIR /app

RUN groupadd \
        --gid "${APP_UID}" \
        appgroup \
    && useradd \
        --uid "${APP_UID}" \
        --gid appgroup \
        --no-create-home \
        --shell /usr/sbin/nologin \
        appuser

COPY requirements.txt requirements.lock /app/

RUN pip install \
        --no-cache-dir \
        --requirement /app/requirements.lock

COPY --chown=appuser:appgroup app/ /app/

USER appuser

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
