import os
import socket
from pathlib import Path

import psycopg
from fastapi import FastAPI, HTTPException


APP_VERSION = "1.0.0"

app = FastAPI(
    title="Segmented Network API",
    version=APP_VERSION,
)


def read_database_password() -> str:
    password_file = os.environ.get(
        "DB_PASSWORD_FILE",
        "/run/secrets/db_password",
    )

    password = Path(password_file).read_text(encoding="utf-8").strip()

    if not password:
        raise RuntimeError("Database password file is empty")

    return password


def open_database_connection() -> psycopg.Connection:
    return psycopg.connect(
        host=os.environ.get("DB_HOST", "database"),
        port=int(os.environ.get("DB_PORT", "5432")),
        dbname=os.environ.get("DB_NAME", "segmentdb"),
        user=os.environ.get("DB_USER", "segmentuser"),
        password=read_database_password(),
        connect_timeout=3,
    )


@app.get("/health")
def health() -> dict[str, str]:
    return {
        "service": "api",
        "status": "healthy",
        "version": APP_VERSION,
    }


@app.get("/identity")
def identity() -> dict[str, object]:
    hostname = socket.gethostname()

    addresses = sorted(
        {
            result[4][0]
            for result in socket.getaddrinfo(hostname, None)
        }
    )

    return {
        "service": "api",
        "hostname": hostname,
        "addresses": addresses,
        "version": APP_VERSION,
    }


@app.get("/database-health")
def database_health() -> dict[str, str]:
    try:
        with open_database_connection() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    SELECT message, created_at
                    FROM network_events
                    ORDER BY id DESC
                    LIMIT 1
                    """
                )
                row = cursor.fetchone()

    except (OSError, RuntimeError, psycopg.Error) as error:
        raise HTTPException(
            status_code=503,
            detail="Database is unavailable",
        ) from error

    if row is None:
        raise HTTPException(
            status_code=503,
            detail="Database contains no network events",
        )

    message, created_at = row

    return {
        "service": "api",
        "database": "connected",
        "message": message,
        "created_at": created_at.isoformat(),
    }
