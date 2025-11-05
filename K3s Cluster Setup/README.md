# K3s Cluster Setup Scripts

Automated scripts for creating and managing a k3s cluster with VPN-based connectivity (tun0). Simple, straightforward setup following production deployment patterns.

---

## Features

- 🚀 Automated master node setup
- 🔗 Automated worker node joining  
- 🔐 VPN-based cluster networking (tun0)
- 🛠️ Production-ready configuration
- 📝 Step-by-step documentation

---

## Prerequisites

### ⚠️ IMPORTANT: OpenVPN Server Required

**This cluster setup requires a working OpenVPN server infrastructure.**

You must have:
- ✅ OpenVPN server configured and running
- ✅ Client certificates (`.ovpn` files) generated
- ✅ VPN network configured (e.g., 10.8.0.0/24)
- ✅ All nodes able to connect to the VPN

**This project does NOT:**
- ❌ Install or configure OpenVPN server
- ❌ Generate VPN certificates
- ❌ Set up VPN infrastructure

**If you don't have OpenVPN set up yet:**
- Follow the [Official OpenVPN Installation Guide](https://openvpn.net/community-resources/how-to/)
- Use [easy-rsa](https://github.com/OpenVPN/easy-rsa) to generate certificates
- See the [Quick OpenVPN Setup Guide](#openvpn-setup-guide) below for basic steps

---

## What You Need

### All Nodes (Master + Workers)

- **Linux System:** Ubuntu 20.04+, Debian 10+, RHEL 8+, or CentOS 8+
- **Root Access:** You need to run commands with `sudo`
- **OpenVPN Client:** Installed and configured with valid `.ovpn` certificate
- **VPN Connection:** Active `tun0` interface connected to your OpenVPN server
- **Minimum Hardware:** 
  - 2 CPU cores
  - 2GB RAM
  - 20GB disk space

### Master Node Specifically

- Port 6443 must be accessible (Kubernetes API) **over VPN**
- Port 10250 must be accessible (kubelet metrics) **over VPN**

---

## How the Cluster Works

```
VPN Network (tun0) - All nodes connected via OpenVPN
┌──────────────────────────────────────────────────┐
│                                                  │
│  Master Node (e.g., 10.8.0.1)                   │
│  ┌────────────────────────────────────┐         │
│  │ k3s server --flannel-iface=tun0    │         │
│  │ Listens on: https://10.8.0.1:6443  │         │
│  └────────────────────────────────────┘         │
│                    ↓                             │
│          Communicates via VPN                    │
│                    ↓                             │
│  ┌────────────────────────────────────┐         │
│  │ Worker 1 (e.g., 10.8.0.2)          │         │
│  │ k3s agent --flannel-iface=tun0     │         │
│  └────────────────────────────────────┘         │
│                    ↓                             │
│  ┌────────────────────────────────────┐         │
│  │ Worker 2 (e.g., 10.8.0.3)          │         │
│  │ k3s agent --flannel-iface=tun0     │         │
│  └────────────────────────────────────┘         │
│                                                  │
└──────────────────────────────────────────────────┘
```

**Key Points:**
- All communication happens over the VPN (tun0)
- Master provides the Kubernetes API at port 6443
- Workers connect to master using VPN IP address
- Flannel (pod network) uses tun0 interface

---

## Step-by-Step Setup Guide

### Step 0: Install OpenVPN Client on All Nodes

**Before starting, install OpenVPN client on every node:**

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install openvpn -y

# CentOS/RHEL
sudo yum install epel-release -y
sudo yum install openvpn -y
```

**Copy your `.ovpn` certificate to the node:**
```bash
# Example: copy certificate file
scp your-certificate.ovpn user@node-ip:~/
```

---

### Step 1: Prepare Your Machines

**On ALL nodes (master and workers):**

1. **Start VPN connection:**
   ```bash
   # Start your VPN connection
   sudo openvpn --config your-vpn-config.ovpn --daemon
   ```

2. **Verify tun0 interface exists:**
   ```bash
   ip addr show tun0
   ```
   
   You should see output like:
   ```
   5: tun0: <POINTOPOINT,MULTICAST,NOARP,UP,LOWER_UP>
       inet 10.8.0.1/24 scope global tun0
   ```
   
   The IP address (e.g., `10.8.0.1`) is your VPN IP - **note this down!**

3. **Test VPN connectivity:**
   ```bash
   # Ping VPN server
   ping 10.8.0.1
   
   # Check if you can reach other nodes on VPN
   ping 10.8.0.2
   ```

4. **Download the setup scripts:**
   ```bash
   cd ~
   git clone <your-repo-url> k3s-cluster
   cd k3s-cluster
   ```

5. **Make scripts executable:**
   ```bash
   chmod +x setup-master.sh setup-worker.sh
   ```

---

### Step 2: Setup the Master Node

**On the master machine:**

1. **Create the configuration file:**
   ```bash
   cp .env.example .env
   nano .env
   ```

2. **Edit `.env` and set:**
   ```bash
   CLUSTER_NAME="my-cluster"        # Choose a name for your cluster
   K3S_VERSION="v1.28.5+k3s1"       # k3s version to install
   ```
   
   Save and exit (Ctrl+X, then Y, then Enter in nano).

3. **Run the master setup script:**
   ```bash
   sudo ./setup-master.sh
   ```

4. **What happens during setup:**
   - Script checks that tun0 is connected
   - Detects your VPN IP automatically (e.g., 10.8.0.1)
   - Asks for confirmation to proceed
   - Downloads and installs k3s server
   - Configures k3s to use tun0 for all networking
   - Generates a secret token for workers to join
   - Creates `example.env` file with all connection details

5. **After successful installation, you'll see:**
   ```
   ✓ Master VPN IP: 10.8.0.1
   ✓ Server URL: https://10.8.0.1:6443
   ✓ Node Token: K10abc123def456...::server:xyz789...
   ✓ Cluster information saved to: example.env
   ```

6. **Important: Save the cluster information!**
   
   The `example.env` file contains:
   - Master VPN IP
   - Cluster join token
   - Commands for workers to join
   
   **Keep this file safe - you'll need it for Step 3!**

---

### Step 3: Configure kubectl Access

**Still on the master node:**

Now you need to configure `kubectl` so you can control the cluster.

1. **Copy the kubeconfig file:**
   ```bash
   mkdir -p ~/.kube
   sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
   ```

2. **Set correct ownership:**
   ```bash
   # Replace 'your-username' with your actual username
   sudo chown your-username:your-username ~/.kube/config
   chmod 600 ~/.kube/config
   ```

3. **Add to your shell configuration:**
   ```bash
   echo 'export KUBECONFIG=$HOME/.kube/config' >> ~/.bashrc
   source ~/.bashrc
   ```

4. **Test kubectl:**
   ```bash
   kubectl get nodes
   ```
   
   You should see your master node listed:
   ```
   NAME     STATUS   ROLES                  AGE   VERSION
   master   Ready    control-plane,master   2m    v1.28.5+k3s1
   ```

**Congratulations!** Your master node is now ready and you can control it with kubectl.

---

### Step 4: Join Worker Nodes

**On each worker machine:**

1. **Ensure VPN is connected:**
   ```bash
   ip addr show tun0
   ```
   
   Note your worker's VPN IP (e.g., 10.8.0.2).

2. **Create the configuration file:**
   ```bash
   cd ~/k3s-cluster  # Where you downloaded the scripts
   cp example.env .env
   nano .env
   ```

3. **Edit `.env` with information from master's `example.env`:**
   ```bash
   CLUSTER_NAME="my-cluster"                    # Same as master
   K3S_VERSION="v1.28.5+k3s1"                   # Same version as master
   NODE_NAME="worker-01"                        # Unique name for THIS worker
   K3S_URL="https://10.8.0.1:6443"              # Master's VPN IP (from example.env)
   K3S_TOKEN="K10abc123...::server:xyz789..."   # Token from example.env
   ```
   
   **Important:**
   - `NODE_NAME` must be unique for each worker (worker-01, worker-02, etc.)
   - `K3S_URL` must use the master's VPN IP address
   - `K3S_TOKEN` is the long secret token from example.env

4. **Run the worker setup script:**
   ```bash
   sudo ./setup-worker.sh
   ```

5. **What happens during setup:**
   - Script checks that tun0 is connected
   - Detects your worker's VPN IP automatically
   - Shows the configuration you set
   - Asks for confirmation to proceed
   - Downloads and installs k3s agent
   - Connects to the master using the token
   - Joins the cluster

6. **After successful installation, you'll see:**
   ```
   ✓ Worker VPN IP: 10.8.0.2
   ✓ Node Name: worker-01
   ✓ Connected to: https://10.8.0.1:6443
   ✓ Worker node joined the cluster
   ```

7. **Verify from master:**
   
   Go back to your master node and run:
   ```bash
   kubectl get nodes
   ```
   
   You should now see both master and worker:
   ```
   NAME        STATUS   ROLES                  AGE   VERSION
   master      Ready    control-plane,master   10m   v1.28.5+k3s1
   worker-01   Ready    <none>                 1m    v1.28.5+k3s1
   ```

8. **Repeat for additional workers:**
   - Connect next worker to VPN
   - Copy and edit `.env` with unique `NODE_NAME` (worker-02, worker-03, etc.)
   - Run `sudo ./setup-worker.sh`

---

## Verifying Your Cluster

### Check All Nodes

```bash
kubectl get nodes -o wide
```

This shows:
- Node names
- Status (should be "Ready")
- Roles
- Age
- k3s version
- Internal IPs (your VPN IPs)

### Check System Pods

```bash
kubectl get pods -A
```

You should see pods running in namespaces:
- `kube-system` - Core Kubernetes components
- `kube-node-lease` - Node heartbeat system

All pods should show `Running` status.

### Check Cluster Info

```bash
kubectl cluster-info
```

Shows where the Kubernetes API and other services are running.

---

## Common Tasks

### View Cluster Status

```bash
# See all nodes
kubectl get nodes

# See all pods in all namespaces
kubectl get pods -A

# See all services
kubectl get svc -A

# Get detailed info about a node
kubectl describe node <node-name>
```

### Deploy a Test Application

```bash
# Create a simple nginx deployment
kubectl create deployment nginx --image=nginx

# Expose it as a service
kubectl expose deployment nginx --port=80 --type=NodePort

# Check the deployment
kubectl get deployments
kubectl get pods

# Get the service details
kubectl get svc nginx
```

### Check Logs

```bash
# Master node logs
sudo journalctl -u k3s -f

# Worker node logs (on worker machine)
sudo journalctl -u k3s-agent -f

# Pod logs
kubectl logs <pod-name> -n <namespace>
```

---

## Troubleshooting

### VPN Not Connected

**Problem:** Script says "VPN interface (tun0) not found"

**Solution:**
```bash
# Check if VPN process is running
ps aux | grep openvpn

# If not running, start it
sudo openvpn --config your-vpn.ovpn --daemon

# Verify tun0 appears
ip addr show tun0

# Test connectivity to VPN server
ping 10.8.0.1

# Check OpenVPN logs
sudo journalctl -u openvpn -f
```

---

### Master Won't Start

**Problem:** k3s service fails to start on master

**Solution:**
```bash
# Check the logs
sudo journalctl -u k3s -f

# Common issues:
# 1. Port 6443 already in use
sudo lsof -i :6443

# 2. Firewall blocking (though VPN should handle this)
sudo ufw allow from 10.8.0.0/24

# 3. VPN IP changed
ip addr show tun0  # Check if IP matches what you expect

# Try reinstalling
sudo /usr/local/bin/k3s-uninstall.sh
sudo ./setup-master.sh
```

---

### Worker Can't Join

**Problem:** Worker fails to connect to master

**Solution:**
```bash
# 1. Check VPN connectivity from worker to master
ping <master-vpn-ip>

# 2. Test if master API is reachable
curl -k https://<master-vpn-ip>:6443/ping

# 3. Verify token is correct
cat .env | grep K3S_TOKEN
# Compare with example.env on master

# 4. Check k3s-agent logs on worker
sudo journalctl -u k3s-agent -f

# 5. Verify NODE_NAME is unique
cat .env | grep NODE_NAME
# Should not match any existing node name

# 6. Check VPN connectivity
traceroute <master-vpn-ip>

# 7. Try reinstalling
sudo /usr/local/bin/k3s-agent-uninstall.sh
sudo ./setup-worker.sh
```

---

### kubectl Not Working

**Problem:** `kubectl: command not found` or "permission denied"

**Solution:**
```bash
# Check if kubeconfig exists
ls -la ~/.kube/config

# If not, copy it
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(whoami):$(whoami) ~/.kube/config

# Set environment variable
export KUBECONFIG=$HOME/.kube/config

# Add to bashrc
echo 'export KUBECONFIG=$HOME/.kube/config' >> ~/.bashrc
source ~/.bashrc

# Test again
kubectl get nodes
```

---

### Node Shows "NotReady"

**Problem:** Node status is "NotReady" instead of "Ready"

**Solution:**
```bash
# Get more details
kubectl describe node <node-name>

# Check if VPN is still connected
ip addr show tun0

# Check node logs
# On master:
sudo journalctl -u k3s -f

# On worker:
sudo journalctl -u k3s-agent -f

# Restart the service
# On master:
sudo systemctl restart k3s

# On worker:
sudo systemctl restart k3s-agent

# Wait a minute then check again
kubectl get nodes
```

---

## Maintenance

### Adding More Workers

1. Ensure worker has OpenVPN client installed
2. Copy VPN certificate to worker
3. Connect worker to VPN
4. Download scripts
5. Copy `.env` from existing worker
6. Change `NODE_NAME` to unique value
7. Run `sudo ./setup-worker.sh`

### Removing a Worker

**On master:**
```bash
# Safely drain the node (move pods to other nodes)
kubectl drain <worker-name> --ignore-daemonsets --delete-emptydir-data

# Delete from cluster
kubectl delete node <worker-name>
```

**On worker machine:**
```bash
# Uninstall k3s agent
sudo /usr/local/bin/k3s-agent-uninstall.sh
```

### Updating k3s Version

**Update master first, then workers:**

```bash
# 1. Update .env file
nano .env
# Change K3S_VERSION="v1.29.0+k3s1"  (new version)

# 2. On master
sudo /usr/local/bin/k3s-uninstall.sh
sudo ./setup-master.sh

# 3. On each worker
sudo /usr/local/bin/k3s-agent-uninstall.sh
sudo ./setup-worker.sh
```

### Backup and Restore

**Create backup (on master):**
```bash
# Take snapshot
sudo k3s etcd-snapshot save

# List snapshots
sudo k3s etcd-snapshot ls

# Snapshots are stored in:
# /var/lib/rancher/k3s/server/db/snapshots/
```

**Restore from backup (on master):**
```bash
# Stop k3s
sudo systemctl stop k3s

# Restore snapshot
sudo k3s etcd-snapshot restore <snapshot-name>

# Start k3s
sudo systemctl start k3s
```

---

## Security Best Practices

### 1. Protect Your Credentials

```bash
# Protect .env file
chmod 600 .env

# Protect example.env
chmod 600 example.env

# Never commit these files to git
echo ".env" >> .gitignore
echo "example.env" >> .gitignore
echo "*.ovpn" >> .gitignore
```

### 2. Use Firewall (on VPN level)

```bash
# On each node - only allow VPN network
sudo ufw default deny incoming
sudo ufw allow from 10.8.0.0/24
sudo ufw enable
```

### 3. Keep System Updated

```bash
# Update system packages regularly
sudo apt update && sudo apt upgrade -y
```

### 4. Monitor Logs

```bash
# Check master logs regularly
sudo journalctl -u k3s --since "1 hour ago"

# Check worker logs
sudo journalctl -u k3s-agent --since "1 hour ago"

# Check VPN logs
sudo journalctl -u openvpn --since "1 hour ago"
```

### 5. VPN Security

- Use strong VPN passwords
- Keep VPN credentials secure
- Regularly update VPN client and server
- Rotate VPN certificates periodically
- Monitor VPN connections
- Use certificate-based authentication (not password)

---

## Complete Uninstallation

### Remove Worker

```bash
# On worker machine
sudo /usr/local/bin/k3s-agent-uninstall.sh
```

### Remove Master

```bash
# On master machine
sudo /usr/local/bin/k3s-uninstall.sh
```

### Clean Up Files

```bash
# Remove kubeconfig
rm -rf ~/.kube

# Remove configuration and cluster info
rm -f .env example.env

# Remove scripts (if desired)
cd ~
rm -rf k3s-cluster
```

---

## File Structure

Your project directory will look like this:

```
k3s-cluster/
├── setup-master.sh      # Script to setup master node
├── setup-worker.sh      # Script to join workers
├── example.env          # Configuration template
├── .env                 # Your configuration (created from .env.example)
├── README.md            # This documentation
└── example.env          # Generated by setup-master.sh (KEEP SECRET!)
```

---

## Quick Reference

### Essential Commands

**On Master:**
```bash
# Setup
sudo ./setup-master.sh

# Check cluster
kubectl get nodes
kubectl get pods -A

# View logs
sudo journalctl -u k3s -f

# Restart service
sudo systemctl restart k3s
```

**On Worker:**
```bash
# Setup
sudo ./setup-worker.sh

# View logs
sudo journalctl -u k3s-agent -f

# Restart service
sudo systemctl restart k3s-agent
```

**VPN:**
```bash
# Check connection
ip addr show tun0

# Start VPN
sudo openvpn --config vpn.ovpn --daemon

# Stop VPN
sudo pkill openvpn

# Check VPN logs
sudo journalctl | grep openvpn
```

---

## Need Help?

- k3s Documentation: https://docs.k3s.io
- Kubernetes Documentation: https://kubernetes.io/docs
- OpenVPN Documentation: https://openvpn.net/community-resources
- OpenVPN Installation Guide: https://openvpn.net/community-resources/how-to/

---


