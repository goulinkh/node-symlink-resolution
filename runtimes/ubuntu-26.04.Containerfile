# kind: debian
# Node.js from Ubuntu's nodejs package, which Ubuntu takes from Debian.
FROM docker.io/library/ubuntu:26.04
RUN apt-get update \
 && apt-get install -y --no-install-recommends nodejs \
 && rm -rf /var/lib/apt/lists/*
