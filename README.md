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
Because the pentest tools run inside isolated Docker containers, they need a safe way to receive wordlists and output scan reports back to your Kali machine. This is handled by mapping a local `/data` directory into the containers.

```bash
# Create the internal directory structure
mkdir -p data/reports data/wordlists data/templates data/temp
```

**What goes inside the `data/` folder?**
*   `/data/reports`: This is where the AI and tools will drop final PDF, HTML, and Markdown vulnerability reports.
*   `/data/wordlists`: Custom dictionaries (like SecLists or Assetnote) downloaded by `bootstrap.sh`. The tools execute from this directory.
*   `/data/templates`: Stores raw YAML nuclei scanner templates.
*   `/data/temp`: Temporary execution files like `alive_subs.txt` or `ferox_results.txt`.

**IMPORTANT:** Transfer your custom `Pentest-Playbook.md` into the root of this `data/` folder before booting.
```bash
cp path/to/your/Pentest-Playbook.md data/
```

### Step 5: Boot the Infrastructure
With the keys configured and the data folder scaffolded, initialize the stack. Docker Compose will automatically pull the official **n8n** image, build the custom Kali tools container, and configure the Tor proxy network.

```bash
# Build the tool containers and start in detached mode
docker-compose up -d --build
```
*Note: The first time you run this command, it will take several minutes to download tools (Nuclei, SQLMap, Feroxbuster) via `bootstrap.sh`. You can monitor the progress by typing: `docker logs -f pentest-tools-api`.*

---

## 💻 Usage & n8n Configuration

### 1. Accessing the n8n Orchestrator
n8n is fully installed and managed automatically via Docker. You do not need to install it on the host OS natively.

1.  Open your browser and navigate to the VM's IP address on port `5678` (e.g., `http://YOUR_VM_IP:5678` or `http://localhost:5678` if running locally).
2.  On the first boot, n8n will prompt you to create a secure local **Owner Account**. Enter an email and strong password.
3.  Once logged in, click **Workflows** on the left sidebar.
4.  Hit **Import from File** (or "Import from URL") and upload the master JSON pentest workflow you designed.

### 2. How the Automation Engine Works
*   The n8n orchestrator acts as the "brain". It listens for trigger commands (like Webhooks or Cron schedules).
*   It issues bash commands via the internal Docker network to the `pentest-tools-api` container.
*   The tools container executes the heavy scans (using `nuclei`, `feroxbuster`, etc.) as root, but safely sandboxed inside its own environment.
*   Vulnerable payloads and crawling engines are safely routed through the internal `tor-proxy` container to mask your VM's true public IP.

### 3. Graceful Shutdown
To completely turn off the pentest infrastructure, run:
```bash
docker-compose down
```
