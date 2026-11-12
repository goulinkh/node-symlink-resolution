# kind: upstream
# Node.js from Fedora's nodejs package. Fedora doesn't change how Node.js
# finds packages.
FROM registry.fedoraproject.org/fedora-minimal:43
RUN microdnf install -y nodejs && microdnf clean all
