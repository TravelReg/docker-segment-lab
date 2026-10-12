# Docker Segmented Microservice Network

A small Docker networking lab demonstrating service isolation across three user-defined bridge networks.

## Architecture

The application contains:

- An NGINX gateway connected to the edge and application networks.
- A Python API connected to the application and data networks.
- A PostgreSQL database connected only to the data network.
- Automated tests for allowed and blocked network paths.

## Network zones

| Network | Purpose |
|---|---|
| `segment_edge` | Entry point and gateway traffic |
| `segment_app` | Communication between the gateway and API |
| `segment_data` | Communication between the API and database |

Only the gateway is published to the Docker host. The API and PostgreSQL database have no published host ports.

## Project status

Work in progress.
