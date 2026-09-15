# --- Stage 1: build a wheel from the uploaded source -----------------------
FROM python:3.12-slim AS builder

WORKDIR /build
COPY . /build

RUN pip install --no-cache-dir --upgrade pip build \
    && python -m build --wheel --outdir /tmp/dist

# --- Stage 2: runtime image, no source tree present -------------------------
FROM python:3.12-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /tmp/dist /tmp/dist
RUN pip install --no-cache-dir /tmp/dist/*.whl && rm -rf /tmp/dist

RUN python3 -c "import insto; print('insto package OK:', insto.__version__, insto.__file__)"

WORKDIR /app

ENV INSTO_HOME=/data
RUN mkdir -p /data/output && chmod 700 /data

COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

ENTRYPOINT ["/app/entrypoint.sh"]
