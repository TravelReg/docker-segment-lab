# Architecture

## Request path

```mermaid
flowchart LR
    USER[Local browser]
    SSH[Termius SSH tunnel]
    GW[NGINX gateway]
    API[Python API]
    DB[(PostgreSQL)]

    USER --> SSH
    SSH --> GW
    GW -->|segment_app| API
    API -->|segment_data| DB
```

## Network membership

| Container | Edge network | Application network | Data network |
|---|---:|---:|---:|
| Gateway | Yes | Yes | No |
| API | No | Yes | Yes |
| Database | No | No | Yes |

The gateway and API are dual-homed containers. Each connects two adjacent network zones.

The gateway is the only service published to the Docker host. The API and database can be reached only through their appropriate Docker networks.
