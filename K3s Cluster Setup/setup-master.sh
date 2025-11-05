#!/bin/bash

# ============================================
# K3s Master Node Setup Script
# Automatically creates k3s master with VPN (tun0)
# ============================================

set -e

# Load environment variables
if [ -f .env ]; then
    set -a
    source .env
    set +a
else
    echo "❌ .env file not found. Please create it before running this script."
    exit 1
fi

# Validate required variables
required_vars=("K3S_VERSION" "CLUSTER_NAME")
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "❌ Missing required environment variable: $var"
        exit 1
    fi
done

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "❌ This script must be run as root or with sudo"
    exit 1
fi

echo ""
echo "=========================================="
echo "  K3s Master Setup - ${CLUSTER_NAME}"
echo "=========================================="
echo ""

# Check VPN connection
if ! ip link show tun0 &> /dev/null; then
    echo "❌ VPN interface (tun0) not found!"
    echo "Please start your VPN connection before creating the master."
    exit 1
fi

# Get tun0 IP
MASTER_VPN_IP=$(ip -4 addr show tun0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
if [ -z "$MASTER_VPN_IP" ]; then
    echo "❌ Could not determine tun0 IP address!"
    exit 1
fi

echo "✓ VPN interface detected"
echo "✓ Master VPN IP: $MASTER_VPN_IP"
echo "✓ K3s Version: $K3S_VERSION"
echo ""

# Confirmation
read -p "Proceed with master setup? (y/n): " confirm
if [ "$confirm" != "y" ]; then
    echo "Master setup cancelled."
    exit 0
fi

# Check if k3s already installed
if command -v k3s &> /dev/null; then
    echo "⚠️  K3s is already installed"
    read -p "Uninstall and reinstall? (y/n): " reinstall
    if [ "$reinstall" = "y" ]; then
        if [ -f /usr/local/bin/k3s-uninstall.sh ]; then
            echo "Uninstalling existing k3s..."
            /usr/local/bin/k3s-uninstall.sh
            sleep 2
            echo "✓ Uninstalled"
        fi
    else
        exit 0
    fi
fi

# Install k3s master
echo ""
echo "Installing k3s master on tun0 ($MASTER_VPN_IP)..."
echo ""

curl -sfL https://get.k3s.io | \
    INSTALL_K3S_VERSION="$K3S_VERSION" \
    INSTALL_K3S_EXEC="server --flannel-iface=tun0" \
    sh -

# Wait for k3s to start
echo ""
echo "Waiting for k3s to start..."
sleep 10

# Check service
if systemctl is-active --quiet k3s; then
    echo "✓ K3s service is running"
else
    echo "❌ K3s service failed to start"
    echo "Check logs: sudo journalctl -u k3s -f"
    exit 1
fi

# Get node token
if [ -f /var/lib/rancher/k3s/server/node-token ]; then
    NODE_TOKEN=$(cat /var/lib/rancher/k3s/server/node-token)
else
    echo "❌ Node token not found"
    exit 1
fi

# Save cluster info
CLUSTER_INFO_FILE="./cluster-info.txt"
cat > "$CLUSTER_INFO_FILE" << EOF
K3s Cluster Information
=======================

Cluster Name: $CLUSTER_NAME
Master VPN IP: $MASTER_VPN_IP
K3s Version: $K3S_VERSION
Server URL: https://$MASTER_VPN_IP:6443
Node Token: $NODE_TOKEN

Worker Join Command:
--------------------
# Ensure VPN (tun0) is connected on worker first!
curl -sfL https://get.k3s.io | \\
  INSTALL_K3S_VERSION="$K3S_VERSION" \\
  INSTALL_K3S_EXEC="agent --flannel-iface=tun0 --node-name=\$NODE_NAME" \\
  K3S_TOKEN="$NODE_TOKEN" \\
  K3S_URL="https://$MASTER_VPN_IP:6443" \\
  sh -

For .env file (workers):
------------------------
K3S_VERSION="$K3S_VERSION"
K3S_URL="https://$MASTER_VPN_IP:6443"
K3S_TOKEN="$NODE_TOKEN"

Important:
- Keep VPN active on master
- All workers must connect to same VPN
- Use VPN IP for all cluster communications
EOF

chmod 600 "$CLUSTER_INFO_FILE"

# Display results
echo ""
echo "=========================================="
echo "  Master Setup Complete!"
echo "=========================================="
echo ""
echo "Cluster Name: $CLUSTER_NAME"
echo "Master VPN IP: $MASTER_VPN_IP"
echo "Server URL: https://$MASTER_VPN_IP:6443"
echo ""
echo "Node Token: $NODE_TOKEN"
echo ""
echo "✓ Cluster information saved to: $CLUSTER_INFO_FILE"
echo ""

# Show nodes
echo "Current Nodes:"
k3s kubectl get nodes
echo ""

echo "=========================================="
echo "  Next Steps"
echo "=========================================="
echo ""
echo "1. Keep VPN (tun0) connection active"
echo "2. Save token from: $CLUSTER_INFO_FILE"
echo "3. Setup kubectl: ./setup-kubectl.sh"
echo "4. Join workers: ./setup-worker.sh"
echo "5. (Optional) Install Rancher: ./setup-rancher.sh"
echo ""
echo "=========================================="
echo ""
