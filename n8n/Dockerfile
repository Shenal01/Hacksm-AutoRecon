FROM docker.n8n.io/n8nio/n8n

USER root

RUN if command -v apk >/dev/null 2>&1; then \
      apk add --no-cache openssh-client sshpass; \
    elif command -v apt-get >/dev/null 2>&1; then \
      apt-get update && apt-get install -y --no-install-recommends openssh-client sshpass && rm -rf /var/lib/apt/lists/*; \
    elif command -v microdnf >/dev/null 2>&1; then \
      microdnf install -y openssh-clients sshpass && microdnf clean all; \
    elif command -v dnf >/dev/null 2>&1; then \
      dnf install -y openssh-clients sshpass && dnf clean all; \
    elif command -v yum >/dev/null 2>&1; then \
      yum install -y openssh-clients sshpass && yum clean all; \
    else \
      echo "Unsupported base image: no known package manager found for installing ssh client dependencies." >&2; \
      exit 1; \
    fi

RUN cat > /usr/local/bin/ssh <<'EOF'
#!/bin/sh
set -eu

if [ -z "${TOOLS_SSH_PASSWORD:-}" ] || [ "${TOOLS_SSH_PASSWORD}" = "replace_with_a_long_random_password" ]; then
  echo "TOOLS_SSH_PASSWORD is not set for n8n SSH execution." >&2
  exit 1
fi

exec sshpass -p "${TOOLS_SSH_PASSWORD}" /usr/bin/ssh "$@"
EOF

RUN chmod 0755 /usr/local/bin/ssh

USER node