# Recon Automation — n8n Workflow

## What is This?

This project is a modular, automated penetration testing workflow built for n8n. It orchestrates a full bug bounty/pentest pipeline using open-source tools, aggregates findings, and generates professional reports. Designed for security teams, bug bounty hunters, and automation enthusiasts.

## Deployment Documentation

For full repo push + VM setup instructions, see:

- `DEPLOYMENT_GUIDE.md`

## Workflow Overview

This workflow is designed as a phased security pipeline with deterministic gates and report-ready outputs.

- **Input Channels:** Webhook trigger for on-demand scans and cron trigger for scheduled monitoring.
- **Execution Engine:** n8n orchestrates all phases and sends controlled commands to the tools container.
- **Data Plane:** Artifacts flow through `/data/temp`, then converge into normalized findings and `/data/reports`.
- **Control Plane:** Merge gates synchronize parallel branches before aggregation.
- **Safety Layer:** Allow-list enforcement, blocked-pattern checks, preflight validation, and error workflow alerts.

## Pipeline Stages

| Stage | Purpose | Typical Outputs |
|---|---|---|
| `1. Intake` | Validate target, scope, and run metadata | normalized input + `scan_id` |
| `2. Preflight` | Verify tools, directories, and templates | binary/version checks, readiness status |
| `3. Discovery` | Build attack surface from passive+active recon | subdomains, DNS, ports, endpoints, JS assets |
| `4. Guided Testing` | Select and run allowed testing commands | tool-specific findings and raw logs |
| `5. Parallel Checks` | Run multiple vulnerability families concurrently | XSS/CVE/LFI/SQLi/API/CORS/403 outputs |
| `6. Aggregation` | Merge branches and normalize findings | severity buckets + coverage metrics |
| `7. Reporting` | Build and persist final report | markdown report on disk + Discord alert |

## Visual Workflow Diagram

The diagram below shows the full flow from trigger to report, including error and cleanup side-paths:

```mermaid
flowchart TB
        %% Main happy-path
        subgraph P1[Phase 1 - Intake]
            Start([Start])
            Input[Validate Input]
            Env[Preflight]
        end

        subgraph P2[Phase 2 - Recon and Mapping]
            Recon[Recon]
            Subenum[Subdomain Enum]
            DNS[DNS]
            Ports[Ports]
            HTTP[HTTP Probe]
            Tech[Tech Fingerprint]
            Crawl[Crawl + History]
            Endpoints[Endpoint Discovery]
            JS[JS Secret Scan]
        end

        subgraph P3[Phase 3 - Guided Testing]
            AI[Decision Engine]
            Allow[Security Gate]
            Exec[Run Approved Cmd]
            Tests[Vuln Tests]
        end

        subgraph P4[Phase 4 - Results]
            Metrics[Aggregate Findings]
            Report[Build Report]
            Save[(Save Report)]
            Notify[[Discord Alert]]
        end

        Start --> Input --> Env --> Recon --> Subenum --> DNS --> Ports --> HTTP --> Tech --> Crawl --> Endpoints --> JS --> AI --> Allow --> Exec --> Tests --> Metrics --> Report
        Report --> Save
        Report --> Notify

        %% Side services
        Error[[Error Handler]]
        Cleanup[[Temp Cleanup]]
        Error -. on failure .-> Notify
        Cleanup -. periodic maintenance .-> Save

        %% Visual styles
        classDef intake fill:#eef7ff,stroke:#2f7fd8,stroke-width:2px,color:#12324f;
        classDef recon fill:#f3fbf5,stroke:#2f9e5f,stroke-width:2px,color:#163d28;
        classDef testing fill:#fff8ec,stroke:#cc8b2f,stroke-width:2px,color:#4a2d10;
        classDef results fill:#f7f2ff,stroke:#7a58b5,stroke-width:2px,color:#2e1e4f;
        classDef support fill:#fff1f1,stroke:#c74444,stroke-width:2px,color:#4f1c1c,stroke-dasharray: 4 3;

        linkStyle default stroke-width:2px;

        class Start,Input,Env intake;
        class Recon,Subenum,DNS,Ports,HTTP,Tech,Crawl,Endpoints,JS recon;
        class AI,Allow,Exec,Tests testing;
        class Metrics,Report,Save,Notify results;
        class Error,Cleanup support;
```

**Reading tip:** follow the center path top to bottom for the happy path, then check dashed arrows for side services.

Legend:
- `Validate Input`: Parse and validate input target and scope.
- `Preflight`: Verify binaries, directories, and template readiness.
- `Subdomain Enum`: Deep subdomain discovery (script + passive tools).
- `Tech Fingerprint`: Detect technologies from live hosts.
- `Endpoint Discovery`: Build endpoint list and discover parameters.
- `Decision Engine`: Select tools based on findings and allow-list policy.
- `Vuln Tests`: XSS, CVE, SQLi, LFI, API, CORS, and 403 checks.
- `Aggregate Findings`: Merge outputs and build normalized severity buckets.

## Why This Design Works

- **Scalable:** expensive test branches run in parallel and merge deterministically.
- **Traceable:** every run is tied to a `scan_id` and explicit temp/report artifacts.
- **Safer-by-default:** command generation is gated by allow-list and blocked-pattern controls.
- **Operationally practical:** failures route to error workflow; stale artifacts are cleaned on schedule.

## Setup & Installation

### 1. Prerequisites
- n8n v1.0+ (self-hosted recommended)
- Docker (for pentest-tools-api container)
- Git, curl, SSH access

### 2. Clone & Prepare
```sh
git clone <repo-url>
cd pentest-automation
```

### 3. Environment Variables
Create a `.env` file or set these in n8n:
- SHODAN_API_KEY
- GITHUB_TOKEN
- DISCORD_WEBHOOK_URL
- GEMINI_API_KEY
- OAST_SERVER
- TOOLS_SSH_PASSWORD
- WPSCAN_API_TOKEN (optional)
- MONITOR_TARGETS (for cron monitor)

### 4. Build & Run Docker Container
```sh
docker-compose up -d
```
- Container installs all required tools and wordlists automatically.

### 5. Import Workflows
- Import `pentest_workflow.json` and `pentest_error_workflow.json` into n8n.

### 6. Start n8n
- Run n8n and configure triggers (webhook, cron).

## Usage Guide

- **Webhook Scan:** Send a POST request to `/start-scan` with `{ "target": "example.com" }`.
- **Scheduled Scan:** Set up cron for weekly monitoring.
- **Reports:** Reports are saved in `/data/reports/` and sent to Discord.
- **Error Alerts:** Failures trigger Discord alerts via the error workflow.

## Security & Concurrency

- Per-scan temp directories prevent file clashes.
- All sensitive data handled via environment variables.
- Discord webhook must be private.
- SSH access should be restricted and non-root.

## Data Retention

- Temp files are stored in `/data/temp/<scan_id>/`.
- Scheduled cleanup removes directories older than 7 days.

## License

MIT
