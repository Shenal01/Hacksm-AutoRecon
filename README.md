# 🚀 AI-Driven Automated Pentest Toolkit (n8n + Docker + Ollama)
This repository contains a fully containerized, autonomous bug bounty and penetration testing framework. It utilizes **n8n** to securely orchestrate over 20+ of the latest industry-standard tools (ProjectDiscovery, x8, feroxbuster) via isolated Docker environments, all directed by local AI Playbooks.

## 📋 Requirements
Tested and built for a fresh **Kali Linux** or Ubuntu VM. 
*   **Minimum Specs:** 4 vCPU, 8GB RAM, 50GB Disk. 
*   **Recommended:** 8 vCPU, 16GB+ RAM (Ideal if using local LLMs).

---

## 🛠️ Deployment Instructions (Fresh VM Guide)

To deploy this entire infrastructure on a brand new Kali/Ubuntu machine, follow these steps exactly:

### Step 1: Install Dependencies on the Host OS
Before doing anything, ensure your new server has Docker and Git installed.
```bash
# Update OS and install prerequisites
sudo apt update && sudo apt upgrade -y
sudo apt install -y git ufw docker.io docker-compose curl jq

# Enable Docker and add your user to the docker group (No sudo needed later)
sudo systemctl enable docker --now
sudo usermod -aG docker $USER

# Log out of SSH and log back in to apply the group permissions!
```

### Step 2: Clone the Repository
Clone this exact setup to your machine.
```bash
git clone https://github.com/YOUR_USERNAME/pentest-automation.git
cd pentest-automation
```

### Step 3: Configure API Keys & Environment
You must configure your API keys (Shodan, GitHub, Discord Webhook) before starting the engine.
```bash
# Copy the example environment file
cp .env.example .env

# Edit the file using nano or vim and paste your specific keys
nano .env
```
*Note: Your `.env` file is excluded from Git, meaning your keys will never accidentally be pushed back to GitHub.*

### Step 4: Create Local Data Folders
The Docker containers require local data directories to share wordlists, playbooks, and generated vulnerability reports.
```bash
# Create the internal directory structure
mkdir -p data/{reports,wordlists,templates,temp}

# Transfer your custom Pentest-Playbook.md into the data folder
# (Optionally use wget or curl to pull it from your private webserver)
cp path/to/your/Pentest-Playbook.md data/
```

### Step 5: Boot the Infrastructure
With the keys configured, simply bring the entire stack online. Docker will automatically pull the newest tool binaries and configure the networking.
```bash
# Build the tool containers and start in detached mode
docker-compose up -d --build
```
*Note: The first time you run this command, it will take several minutes to download tools (Nuclei, SQLMap, Feroxbuster) via `bootstrap.sh`. You can monitor the progress by typing: `docker logs -f pentest-tools-api`.*

---

## 💻 Usage & Verification

### 1. Accessing n8n
Once `docker-compose` finishes:
1.  Open your browser and navigate to the VM's IP address on port `5678` (e.g., `http://YOUR_VM_IP:5678`).
2.  Follow the prompts to create your local Owner account for n8n.
3.  Navigate to **Workflows**, hit **Import**, and upload your JSON workflow templates.

### 2. How it Works
*   The n8n orchestrator listens for trigger commands.
*   It routes requests via SSH/API to the `pentest-tools-api` container, which runs as `root` locally but is completely sandboxed from your VM.
*   Python/Ruby testing tools inside the container run inside highly isolated `pipx` or `gem` environments to prevent version crashes.
*   Vulnerable payloads are safely routed through the internal `tor-proxy` container.

### 3. Graceful Shutdown
To completely turn off the pentest infrastructure, run:
```bash
docker-compose down
```
