FROM python:3.12-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
    && rm -rf /var/lib/apt/lists/*

# Install runtime dependencies directly (mirrors [project.dependencies] in
# pyproject.toml). We deliberately do NOT `pip install .` / build a wheel:
# the hatchling wheel build was silently dropping insto/__init__.py in this
# environment (cause unconfirmed), so instead we install deps by name and
# place the insto source on the Python path ourselves below. This sidesteps
# the packaging step entirely rather than depending on debugging it further.
RUN pip install --no-cache-dir \
        "hikerapi>=0.1.0" \
        "httpx>=0.27" \
        "prompt_toolkit>=3.0.43" \
        "rich>=13.7" \
        "tomli-w>=1.0" \
        "tqdm>=4.66"

# Copy the actual insto package source straight into site-packages.
COPY insto /usr/local/lib/python3.12/site-packages/insto

# Recreate the `insto` console-script entry point that `pip install .`
# would normally generate (see [project.scripts] in pyproject.toml).
RUN printf '#!/usr/local/bin/python3\nimport sys\nfrom insto.cli import main\n\nif __name__ == "__main__":\n    sys.exit(main())\n' \
        > /usr/local/bin/insto \
    && chmod +x /usr/local/bin/insto

# Build-time sanity check: fail here (not at `docker run`) if something
# about the package is broken.
RUN python3 -c "import insto; print('insto package OK:', insto.__version__, insto.__file__)" \
    && python3 -c "from insto.cli import main; print('insto.cli import OK')"

WORKDIR /app

# Persistent state (config.toml, store.db, logs) lives under $INSTO_HOME.
# On Railway this should be a mounted Volume so it survives redeploys.
ENV INSTO_HOME=/data
RUN mkdir -p /data/output && chmod 700 /data

COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

ENTRYPOINT ["/app/entrypoint.sh"]
