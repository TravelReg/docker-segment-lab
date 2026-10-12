# Packet Flow

## Application request

A request to the database health endpoint follows this path:

1. The local browser connects to a local Termius tunnel.
2. Termius forwards the connection through SSH.
3. SSH sends the connection to `127.0.0.1:8080` on the Droplet.
4. Docker forwards the host connection to the NGINX gateway.
5. NGINX sends the API request through `segment_app`.
6. The API queries PostgreSQL through `segment_data`.
7. The response returns through the same path.

## Expected allowed paths

| Source | Destination | Reason |
|---|---|---|
| Droplet loopback | Gateway | Explicit port publication |
| Edge probe | Gateway | Shared edge network |
| Gateway | API | Shared application network |
| API | PostgreSQL | Shared data network |

## Expected blocked paths

| Source | Destination | Reason |
|---|---|---|
| Public internet | Gateway port 8080 | Port binds only to loopback |
| Edge probe | API | No shared network |
| Edge probe | PostgreSQL | No shared network |
| Gateway | PostgreSQL | No shared network |
| Application probe | PostgreSQL | No shared network |
| API | Public internet | Attached only to internal networks |
| PostgreSQL | Public internet | Attached only to an internal network |

