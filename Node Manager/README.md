# Node Manager for k3s TEMA Cluster

An automated tool to simplify the configuration, deployment, and management of nodes in a **k3s TEMA cluster** with integrated OpenVPN connectivity.

---

## Features

- 🚀 Automated node setup with VPN integration
- 🔐 Automatic VPN certificate generation
- 🔧 Interactive node type selection (cloud/edge)
- 🎮 Optional NVIDIA GPU support
- 📊 Node and VPN status monitoring
- ⚙️ Start/stop node and VPN operations
- 🗑️ Clean node removal from cluster
- 🔄 Automatic VPN restart on system reboot (via cron)

---

## Prerequisites

### System Requirements

- **Operating System:** Linux-based distribution (Ubuntu, Debian, RHEL, CentOS)
- **Permissions:** Root or sudo access
- **Network:** Active internet connection

### GPU Support (Optional - NVIDIA Only)

To enable GPU acceleration:

1. **NVIDIA GPU** - Compatible NVIDIA GPU installed
2. **NVIDIA Drivers** - Latest drivers for your GPU model
3. **NVIDIA Container Toolkit** - Required for GPU passthrough to containers  → [Installation Guide](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)

**Verify GPU Setup:**
```bash
nvidia-smi
```

---

## Project Structure

```
tema-node-manager/
├── node_manager.sh       # Main management script
├── join_cluster.sh       # Cluster join and setup script
├── startVpn.sh           # VPN auto-start script (used by cron)
├── example.env           # Example environment configuration
└── .env                  # Your actual configuration (create from .env.example)
```

---

## Installation

### 1. Clone the Repository

```bash
git clone <repository-url>
cd <repository-directory>
```

### 2. Configure Environment

```bash
# Copy example configuration
cp example.env .env

# Edit with your actual values
nano .env
```

### 3. Configure `.env` File

Edit the `.env` file with your TEMA cluster configuration:

```bash
# === General Paths ===
VPN_DIR="/opt/tema/vpn"

# === Partner Names ===
# Available partner organizations in TEMA network
PARTNER_NAMES=("auth" "dlr" "eng" "atos" "use" "tsyl" "nd" "plus" "lc" "lat40" "ns" "fhhi" "unime" "kamk" "kaj" "kemea" "other")

# === VPN Configuration ===
VPN_STATUS_URL="http://your-vpn-server.com:8999/status"
VPN_GEN_CERT_URL="http://your-vpn-server.com:8999/gen-cert"
VPN_USER="your_vpn_username"
VPN_PASSWORD="your_vpn_password"

# === Kubernetes (K3s) Configuration ===
K3S_URL="https://your-k3s-master:6443"
K3S_TOKEN="your_k3s_token"
INSTALL_K3S_VERSION="v1.28.5+k3s1"

```

### 4. Make Scripts Executable

```bash
chmod +x node_manager.sh join_cluster.sh startVpn.sh
```

### 5. Run the Main Script

```bash
sudo bash node_manager.sh
```

---

## How It Works

### First Run: Initial Setup

When you run `node_manager.sh` for the first time (k3s not installed), it automatically launches `join_cluster.sh`:

#### Step 1: Organization Name
```
TEMA Cluster Node Setup
=======================
Enter your organization name: unime
```
The script converts it to lowercase and validates it against available partner names.

#### Step 2: Node Type Selection
```
Select node type:
  1) cloud
  2) edge
Your choice: 2
```

#### Step 3: GPU Support
```
Enable GPU support? (y/n): y
```

#### Step 4: VPN Setup
The script automatically:
- Checks VPN server status
- Generates unique node name: `unime-edge-xxxxx` (random suffix)
- Requests VPN certificate from server
- Downloads `.ovpn` configuration file
- Saves it in `VPN_DIR`

#### Step 5: K3s Installation
The script:
- Installs k3s agent with specified version
- Configures node labels based on type (cloud/edge)
- Adds GPU support if enabled
- Joins the cluster using `K3S_URL` and `K3S_TOKEN`
- Starts k3s-agent service

#### Step 6: VPN Auto-Start
Adds cron job for automatic VPN restart on reboot:
```bash
@reboot /bin/bash /path/to/startVpn.sh
```

---

### Subsequent Runs: Node Management

After initial setup, when you run `node_manager.sh`, the script displays:

#### Status Display
```
   TEMA NODE MANAGEMENT
+------------------------+
|  K3s Status: active    |
|  VPN Status: active    |
+------------------------+
```
- **Green "active"** = Service is running
- **Red "inactive"** = Service is stopped

#### Dynamic Menu

The menu adapts based on current node state:

**If node is running:**
```
Cluster Node Control

1. Stop K3s node
2. Remove K3s node
0. Exit

Choose an option:
```

**If node is stopped:**
```
Cluster Node Control

1. Start K3s node
2. Remove K3s node
0. Exit

Choose an option:
```

---

## Available Operations

### Option 1: Start/Stop K3s Node (Dynamic)

This option toggles based on the current state of the k3s-agent service.

#### When Node is Stopped - "Start K3s node"

**What happens:**
1. Starts OpenVPN daemon with your `.ovpn` config
2. Waits 5 seconds for VPN tunnel (`tun0`) to establish
3. Starts k3s-agent service
4. Adds cron job for VPN auto-start on reboot

**Example output:**
```bash
$ sudo bash node_manager.sh
# Choose option 1

Starting VPN...
K3s node is already running.
Starting K3s node...
K3s node started successfully!
```

#### When Node is Running - "Stop K3s node"

**What happens:**
1. Stops OpenVPN process
2. Stops k3s-agent service
3. Removes VPN auto-start cron job

**Example output:**
```bash
$ sudo bash node_manager.sh
# Choose option 1

Stopping VPN.
Stopping K3s node...
K3s node stopped successfully!
```

### Option 2: Remove K3s Node

Completely removes the node from the TEMA cluster.

**Confirmation required:**
```
Are you sure you want to remove this node from the TEMA cluster? Type 'remove' to proceed:
```

**What happens when you type "remove":**
1. Stops VPN and k3s-agent services
2. Removes VPN auto-start cron job
3. Runs `/usr/local/bin/k3s-agent-uninstall.sh`
4. Removes all k3s components and configurations

**Example output:**
```bash
$ sudo bash node_manager.sh
# Choose option 2

Are you sure you want to remove this node from the TEMA cluster? Type 'remove' to proceed: remove

Removing node from TEMA cluster...
Stopping VPN.
Stopping K3s node...
K3s node stopped successfully!
Node removed from TEMA cluster successfully.
```

**If you type anything else:**
```
Removal aborted.
```

**Warning:** After removal, you must run the initial setup again to rejoin the cluster.

---

## Configuration Details

### Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `VPN_DIR` | Directory for VPN certificates | `/opt/tema/vpn` |
| `PARTNER_NAMES` | Array of valid partner names | `("unime" "dlr" "eng")` |
| `VPN_STATUS_URL` | VPN server status endpoint | `http://server:8999/status` |
| `VPN_GEN_CERT_URL` | VPN certificate generation endpoint | `http://server:8999/gen-cert` |
| `VPN_USER` | VPN server authentication username | `admin` |
| `VPN_PASSWORD` | VPN server authentication password | `secure_password` |
| `K3S_URL` | Kubernetes master server URL | `https://master:6443` |
| `K3S_TOKEN` | K3s cluster join token | `K10abc...` |
| `INSTALL_K3S_VERSION` | Specific k3s version to install | `v1.28.5+k3s1` |

### Generated Files

After setup, the following files are created:

**VPN Configuration:**
```
$VPN_DIR/
└── <partner>-<type>-<random>.ovpn
```

**K3s Configuration:**
```
/etc/rancher/k3s/
├── k3s.yaml           # Kubeconfig
└── config.yaml        # K3s agent config

/var/lib/rancher/k3s/  # K3s data directory
```

**Cron Job:**
```bash
# View cron jobs
sudo crontab -l

# Example entry:
@reboot /bin/bash /opt/tema/src/startVpn.sh
```

---

## Troubleshooting

### VPN Connection Issues

**Problem:** VPN fails to start or connect

**Solutions:**
1. Check VPN server is accessible:
   ```bash
   curl -u $VPN_USER:$VPN_PASSWORD $VPN_STATUS_URL
   ```
2. Verify `.ovpn` file exists in `VPN_DIR`:
   ```bash
   ls -la $VPN_DIR/*.ovpn
   ```
3. Test OpenVPN manually:
   ```bash
   sudo openvpn --config $VPN_DIR/your-config.ovpn
   ```
4. Check if VPN process is running:
   ```bash
   pgrep -x openvpn
   ps aux | grep openvpn
   ```

### K3s Agent Won't Start

**Problem:** k3s-agent service fails to start

**Solutions:**
1. Check VPN is connected first (k3s requires VPN):
   ```bash
   ip link show tun0
   ```
2. Verify k3s-agent service status:
   ```bash
   sudo systemctl status k3s-agent
   ```
3. Check k3s logs:
   ```bash
   sudo journalctl -u k3s-agent -f
   ```
4. Verify `K3S_URL` and `K3S_TOKEN` in `.env` are correct

### "No .ovpn file found" Error

**Problem:** Script reports no VPN configuration file

**Solutions:**
1. Check if `.ovpn` file exists in `src/` directory:
   ```bash
   ls -la ./src/*.ovpn
   ```
2. Re-run initial setup to regenerate certificate:
   ```bash
   sudo /usr/local/bin/k3s-agent-uninstall.sh
   sudo bash node_manager.sh
   ```

### Certificate Generation Failed

**Problem:** VPN certificate generation returns error

**Solutions:**
1. Verify VPN server credentials in `.env`:
   ```bash
   echo $VPN_USER
   echo $VPN_PASSWORD
   ```
2. Test VPN API manually:
   ```bash
   curl -X POST $VPN_GEN_CERT_URL \
     -u $VPN_USER:$VPN_PASSWORD \
     -F "name=test-node"
   ```
3. Check if VPN server has available certificates

### Node Not Appearing in Cluster

**Problem:** Node doesn't show up in `kubectl get nodes`

**Solutions:**
1. Verify k3s-agent is running:
   ```bash
   sudo systemctl status k3s-agent
   ```
2. Check VPN connection:
   ```bash
   ip link show tun0
   ip addr show tun0
   ```
3. Verify K3S_TOKEN is correct
4. Check node logs for errors:
   ```bash
   sudo journalctl -u k3s-agent | tail -50
   ```

### GPU Not Detected

**Problem:** GPU support enabled but not working

**Solutions:**
1. Verify NVIDIA drivers:
   ```bash
   nvidia-smi
   ```
2. Check NVIDIA Container Toolkit:
   ```bash
   docker run --rm --gpus all nvidia/cuda:11.8.0-base-ubuntu22.04 nvidia-smi
   ```
3. Verify k3s was installed with GPU support enabled

---

## Security Recommendations

1. **Protect `.env` file:** Contains sensitive credentials
   ```bash
   chmod 600 .env
   ```

2. **Secure VPN certificates:** Restrict access to VPN directory
   ```bash
   chmod 700 $VPN_DIR
   chmod 600 $VPN_DIR/*.ovpn
   ```

3. **Use strong passwords:** Set secure `VPN_PASSWORD` and `K3S_TOKEN`

4. **Regular updates:** Keep k3s, OpenVPN, and system packages updated

5. **Firewall rules:** Only allow necessary ports (6443 for k3s, 1194 for VPN)

6. **Monitor logs:** Regularly check logs for suspicious activity
   ```bash
   sudo journalctl -u k3s-agent -f
   pgrep -a openvpn
   ```

---

## Uninstallation

### Complete Removal

#### Option 1: Using the Script (Recommended)

```bash
sudo bash node_manager.sh
# Choose option 2: Remove K3s node
# Type 'remove' when prompted
```

This automatically handles:
- VPN disconnection
- K3s agent uninstallation
- Cron job removal
- Configuration cleanup

---

## Requirements Summary

| Component | Required | Optional | Notes |
|-----------|----------|----------|-------|
| Linux OS | ✓ | | Ubuntu 20.04+ recommended |
| OpenVPN | ✓ | | Required for cluster connectivity |
| curl | ✓ | | For API requests |
| Root Access | ✓ | | Required for system configuration |
| NVIDIA GPU | | ✓ | Only for GPU-accelerated workloads |
| NVIDIA Drivers | | ✓ | Required if GPU enabled |
| Container Toolkit | | ✓ | Required if GPU enabled |

---

