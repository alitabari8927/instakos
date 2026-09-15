FROM python:3.12-slim

# System deps kept minimal; insto itself is pure-python (hikerapi backend).
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy source and install. Using pip install . (not PyPI) since we're
# shipping the exact code from the uploaded zip.
COPY . /app
RUN pip install --no-cache-dir .

# Persistent state (config.toml, store.db, logs) lives under $INSTO_HOME.
# On Railway this should be a mounted Volume so it survives redeploys.
ENV INSTO_HOME=/data
RUN mkdir -p /data/output && chmod 700 /data

COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

ENTRYPOINT ["/app/entrypoint.sh"]
