# kind: upstream
# The official Node.js image. It is based on Debian, but its node binary is
# the unmodified build from nodejs.org, installed in /usr/local. It doesn't
# use Debian's nodejs package.
FROM docker.io/library/node:24-slim
