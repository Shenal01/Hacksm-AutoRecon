FROM alpine:3.22 AS sshpass-builder

RUN apk add --no-cache sshpass

FROM docker.n8n.io/n8nio/n8n

USER root

# Copy only sshpass from the builder stage so the final n8n image does not need
# a package manager available at build time.
COPY --from=sshpass-builder /usr/bin/sshpass /usr/bin/sshpass

RUN command -v /usr/bin/ssh >/dev/null 2>&1 || \
    (echo "Expected ssh client missing in base n8n image." >&2; exit 1)

RUN cat > /usr/local/bin/ssh <<'EOF'
#!/bin/sh
set -eu

if [ -z "${TOOLS_SSH_PASSWORD:-}" ] || [ "${TOOLS_SSH_PASSWORD}" = "replace_with_a_long_random_password" ]; then
  echo "TOOLS_SSH_PASSWORD is not set for n8n SSH execution." >&2
  exit 1
fi

exec /usr/bin/sshpass -p "${TOOLS_SSH_PASSWORD}" /usr/bin/ssh "$@"
EOF

RUN chmod 0755 /usr/local/bin/ssh

USER node