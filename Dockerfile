FROM python:3.12-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir \
        "hikerapi>=0.1.0" \
        "httpx>=0.27" \
        "prompt_toolkit>=3.0.43" \
        "rich>=13.7" \
        "tomli-w>=1.0" \
        "tqdm>=4.66"

COPY insto /usr/local/lib/python3.12/site-packages/insto

RUN test -f /usr/local/lib/python3.12/site-packages/insto/__init__.py \
        && echo "note: __init__.py WAS present after COPY (will overwrite anyway)" \
        || echo "note: __init__.py was MISSING after COPY (confirms the repo/context issue)"
RUN printf '__version__ = "0.7.22"  # x-release-please-version\n' \
        > /usr/local/lib/python3.12/site-packages/insto/_version.py \
    && printf 'from insto._version import __version__\n\n__all__ = ["__version__"]\n' \
        > /usr/local/lib/python3.12/site-packages/insto/__init__.py

RUN printf '#!/usr/local/bin/python3\nimport sys\nfrom insto.cli import main\n\nif __name__ == "__main__":\n    sys.exit(main())\n' \
        > /usr/local/bin/insto \
    && chmod +x /usr/local/bin/insto

RUN python3 -c "import insto; print('insto package OK:', insto.__version__, insto.__file__)" \
    && python3 -c "from insto.cli import main; print('insto.cli import OK')"

WORKDIR /app

ENV INSTO_HOME=/data
RUN mkdir -p /data/output && chmod 700 /data

COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

ENTRYPOINT ["/app/entrypoint.sh"]
