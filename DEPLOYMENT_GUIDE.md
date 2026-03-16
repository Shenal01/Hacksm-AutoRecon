# Pentest Automation Deployment Guide

This guide covers:
- Creating a GitHub repository and pushing this project
- Setting it up on a VM (Docker-based)
- Running first scan and verifying everything works

## 1. Push This Project to GitHub

### 1.1 Verify local repo state
Run in your local project folder:

```powershell
cd "c:\Users\User\Downloads\New folder\Recon-Reserach\pentest-automation"
git status
git branch
```

### 1.2 Create `.env` locally (do not commit secrets)

```powershell
copy .env.example .env
```

Edit `.env` with real values. Keep `.env` out of git.

### 1.3 Ensure `.env` is ignored
Check `.gitignore` contains:

```gitignore
.env
```

### 1.4 Commit project

```powershell
git add .
git commit -m "feat: production-ready pentest automation workflow"
```

### 1.5 Create GitHub repository
Option A (Web UI):
1. Open GitHub and create a new empty repo (no README, no .gitignore).
2. Copy repo URL, for example: `https://github.com/<your-user>/<repo-name>.git`

Option B (GitHub CLI):

```powershell
gh repo create <repo-name> --private --source . --remote origin --push
```

### 1.6 Link and push (if using Web UI)

```powershell
git remote remove origin 2>$null
git remote add origin https://github.com/<your-user>/<repo-name>.git
git push -u origin HEAD
```

`HEAD` pushes your current checked-out branch (for example `main` or `master`) and avoids branch-name mismatch errors.

## 2. Prepare VM (Ubuntu 22.04/24.04 recommended)

## 2.1 Basic packages

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl git gnupg lsb-release
```

## 2.2 Install Docker Engine + Compose plugin

```bash
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo $VERSION_CODENAME) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

## 2.3 Allow your user to run Docker

```bash
sudo usermod -aG docker $USER
newgrp docker
```

## 2.4 (Optional but recommended) firewall

```bash
sudo ufw allow OpenSSH
sudo ufw allow 5678/tcp
sudo ufw enable
sudo ufw status
```

If n8n should not be public, do not open `5678` globally. Restrict via security group, VPN, or reverse proxy auth.

## 3. Deploy on VM

### 3.1 Clone repository

```bash
git clone https://github.com/<your-user>/<repo-name>.git
cd <repo-name>
```

### 3.2 Create environment file

```bash
cp .env.example .env
nano .env
```

Set all required values:
- `SHODAN_API_KEY`
- `GITHUB_TOKEN`
- `DISCORD_WEBHOOK_URL`
- `GEMINI_API_KEY`
- `WPSCAN_API_TOKEN`
- `OAST_SERVER`
- `TOOLS_SSH_PASSWORD`
- `MONITOR_TARGETS`
- `N8N_BASIC_AUTH_ACTIVE=true`
- `N8N_BASIC_AUTH_USER`
- `N8N_BASIC_AUTH_PASSWORD`

### 3.3 Start stack

```bash
docker compose up -d --build
```

### 3.4 Watch startup/health

```bash
docker compose ps
docker compose logs -f pentest-tools-api
docker compose logs -f n8n
```

Wait until bootstrap completes and services are healthy.

## 4. Import/Configure Workflows in n8n

1. Open n8n: `http://<vm-ip>:5678`
2. Log in using basic auth from `.env`
3. Import:
- `pentest_workflow.json`
- `pentest_error_workflow.json`
4. Activate workflows
5. Verify main workflow setting points to `Pentest Error Handler`

## 5. Run First Smoke Test

### 5.1 Trigger manual scan

```bash
curl -X POST "http://<vm-ip>:5678/webhook/start-scan" \
  -u "<N8N_BASIC_AUTH_USER>:<N8N_BASIC_AUTH_PASSWORD>" \
  -H "Content-Type: application/json" \
  -d '{"target":"example.com"}'
```

If you intentionally disabled basic auth (`N8N_BASIC_AUTH_ACTIVE=false`), remove the `-u` flag.

### 5.2 Validate expected outputs
Check in n8n execution:
- Phase 5 runs parallel branches
- Merge gates complete
- Aggregate node has findings/coverage
- Report generated and saved
- Discord completion alert sent

Check files in container:

```bash
docker exec -it pentest-tools-api bash -lc 'ls -lah /data/reports | tail -n 20'
docker exec -it pentest-tools-api bash -lc 'ls -lah /data/temp | tail -n 50'
```

## 6. Daily Operations

### 6.1 Update images and restart

```bash
git pull
docker compose up -d --build
```

### 6.2 Check service health quickly

```bash
docker compose ps
docker compose logs --tail=200 n8n
docker compose logs --tail=200 pentest-tools-api
```

### 6.3 Backup n8n + reports
Backup these paths regularly:
- Docker volume for n8n data (`n8n_data`)
- `./data/reports`
- `./data` if you need temp/baseline artifacts

Example report backup:

```bash
tar -czf reports-backup-$(date +%F).tar.gz data/reports
```

## 7. Security Checklist (Production)

- Keep `.env` only on host, never commit it
- Use strong random values for:
  - `TOOLS_SSH_PASSWORD`
  - `N8N_BASIC_AUTH_PASSWORD`
- Restrict n8n network exposure (`5678`) to trusted IP/VPN
- Rotate tokens (GitHub, Shodan, Gemini, WPScan, Discord) periodically
- Keep host and Docker updated

## 8. Troubleshooting

### n8n cannot connect to tools container via SSH
- Check `TOOLS_SSH_PASSWORD` matches in both services
- Check container is healthy:

```bash
docker compose ps
docker compose logs pentest-tools-api --tail=200
```

### Tool missing error in preflight
- Rebuild tools image:

```bash
docker compose build --no-cache pentest-tools-api
docker compose up -d
```

### n8n build fails with "Unsupported base image: no known package manager found"
- Cause: new upstream `docker.n8n.io/n8nio/n8n` images no longer expose a package manager in the final stage.
- Fix: pull latest repo and rebuild only `n8n`:

```bash
git pull
docker compose build --no-cache n8n
docker compose up -d
```

- You do not need to re-clone the repository for this issue.

### tor-proxy keeps restarting with "Unknown option 'PASSWORD'"
- Cause: `dperson/torproxy` treats passed env keys as Tor config options; `TOR_PASSWORD` ends up as unsupported `PASSWORD`.
- Fix: remove `TOR_PASSWORD` from `docker-compose.yml` and `.env`, then remove and recreate tor service to clear stale state:

```bash
docker compose rm -sfv tor-proxy
docker compose up -d tor-proxy
docker compose ps
docker compose logs --since=2m tor-proxy
```

### tor-proxy warns about public Socks/TransPort bindings
- Log warnings like `0.0.0.0:9050` or `0.0.0.0:9040` mean Tor is reachable on all interfaces.
- If host-level access to Tor is not required, bind published ports to localhost only in `docker-compose.yml`:

```yaml
ports:
  - "127.0.0.1:9050:9050"
  - "127.0.0.1:8118:8118"
```

### No report generated
- Open failed execution in n8n and inspect nodes:
  - `Collect Coverage Metrics`
  - `Aggregate All Scan Findings`
  - `Phase 7A/7B`

### Webhook returns 404
- Ensure workflow is active in n8n
- Confirm endpoint path is exactly `/webhook/start-scan`

## 9. Recommended First Production Run

Use a domain you own and are authorized to test. Start with a low-risk target and monitor:
- CPU/RAM usage on VM
- Runtime of each phase
- False positives in final report

Once stable, expand target scope and schedule cron runs.
