FROM python:3.12-slim

RUN apt-get update && apt-get install -y --no-install-recommends curl && \
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN npm install -g supergateway
RUN pip install --no-cache-dir mempalace==3.0.0

ENTRYPOINT ["supergateway"]
