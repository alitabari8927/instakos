# --- Stage 1: build a wheel from the uploaded source -----------------------
FROM python:3.12-slim AS builder

WORKDIR /build
COPY . /build

# Build an actual wheel (instead of `pip install .` in place) so nothing
# about the source tree's location can leak into the final image.
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

# Build-time sanity check + self-heal (see scripts/_build_verify.py): prints
# what actually landed in site-packages, patches __init__.py/_version.py if
# insto.__version__ is missing, and fails the BUILD (not a later `docker
# run`) if it still can't be fixed.
COPY scripts/_build_verify.py /tmp/_build_verify.py
RUN python3 /tmp/_build_verify.py && rm /tmp/_build_verify.py

WORKDIR /app

# Persistent state (config.toml, store.db, logs) lives under $INSTO_HOME.
# On Railway this should be a mounted Volume so it survives redeploys.
ENV INSTO_HOME=/data
RUN mkdir -p /data/output && chmod 700 /data

COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

ENTRYPOINT ["/app/entrypoint.sh"]
