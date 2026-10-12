# Threat Model

## Assets

- Database password
- PostgreSQL data
- API service
- Droplet host
- SSH private key

## Trust boundaries

- The public internet and Droplet host
- The edge Docker network
- The application Docker network
- The data Docker network

## Intended protections

- Only SSH is publicly accessible.
- The gateway binds only to the Droplet loopback interface.
- The API has no published host port.
- PostgreSQL has no published host port.
- Containers join only the networks they require.
- The API and database cannot directly access the internet.
- The database password is excluded from Git.

## Important limitation

Docker network segmentation controls network membership. It does not provide directional firewall rules between containers that share the same network.

For example, the API and database both belong to the data network. If the API listens on that network, another member of the data network may be able to connect to it.

Directional packet filtering will be demonstrated in the separate firewall-router project.

## Out of scope

This project does not claim to provide:

- A complete production security platform
- A web application firewall
- Intrusion detection
- Container image vulnerability management
- Host operating-system hardening
