# Contracts: Docker Multi-Stage Builds & Docker Compose

This feature modifies Docker infrastructure configuration only. There are no external interfaces, APIs, or schemas to document.

The Docker Compose services expose the following internal ports for local development:

| Service | Internal Port | External Port | Protocol |
|---------|--------------|---------------|----------|
| app | 8080 | 8080 | HTTP |
| postgres | 5432 | 5432 | TCP |
| redis | 6379 | 6379 | TCP |
| kafka | 9092 | 9092 | TCP |
| kafka | 9094 | 9094 | TCP (external listener) |
