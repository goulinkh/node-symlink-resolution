# kind: debian
# Node.js from Debian's nodejs package.
FROM docker.io/library/debian:13-slim
RUN apt-get update \
 && apt-get install -y --no-install-recommends nodejs \
 && rm -rf /var/lib/apt/lists/*
