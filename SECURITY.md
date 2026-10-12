# Security Policy

This repository is an educational Docker networking lab.

## Sensitive files

Never commit:

- Database passwords
- SSH private keys
- Access tokens
- `.env` files
- Packet captures containing sensitive traffic
- Production data

## Deployment warning

The demonstration services are not intended to be exposed directly to the public internet.

Only SSH should be publicly accessible on the demonstration Droplet. The gateway is intended to bind to `127.0.0.1` and be reached through an SSH tunnel.

## Reporting problems

If a secret is committed accidentally:

1. Treat the secret as compromised.
2. Replace the secret immediately.
3. Remove it from the Git history.
4. Review application and SSH logs for unexpected use.
