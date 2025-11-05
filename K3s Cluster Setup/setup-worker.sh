#!/bin/bash

# ============================================
# K3s Worker/Agent Node Setup Script
# Automatically joins worker to k3s master via VPN (tun0)
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
required_vars=("K3S_VERSION" "K3S_URL" "K3S_TOKEN" "NODE_NAME")
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
echo "  K3s Worker Setup"
echo "=========================================="
echo ""

# Check VPN connection
if ! ip link show tun0 &> /dev/null; then
    echo "❌ VPN interface (tun0) not found!"
    echo "Please start your VPN connection before joining the cluster."
    exit 1
fi

# Get tun0 IP
WORKER_VPN_IP=$(ip -4 addr show tun0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
if [ -z "$WORKER_VPN_IP" ]; then
    echo "❌ Could not determine tun0 IP address!"
    exit 1
fi

echo "✓ VPN interface detected"
echo "✓ Worker VPN IP: $WORKER_VPN_IP"
echo "✓ Node Name: $NODE_NAME"
echo "✓ K3s Version: $K3S_VERSION"
echo "✓ Master URL: $K3S_URL"
echo ""

# Confirmation
read -p "Proceed with worker setup? (y/n): " confirm
if [ "$confirm" != "y" ]; then
    echo "Worker setup cancelled."
    exit 0
fi

# Check if k3s already installed
if command -v k3s &> /dev/null; then
    echo "⚠️  K3s is already installed"
    read -p "Uninstall and reinstall? (y/n): " reinstall
    if [ "$reinstall" = "y" ]; then
        if [ -f /usr/local/bin/k3s-agent-uninstall.sh ]; then
            echo "Uninstalling existing k3s agent..."
            /usr/local/bin/k3s-agent-uninstall.sh
            sleep 2
            echo "✓ Uninstalled"
        fi
    else
        exit 0
    fi
fi

# Install k3s agent
echo ""
echo "Installing k3s agent..."
echo ""

curl -sfL https://get.k3s.io | \
    INSTALL_K3S_VERSION="$K3S_VERSION" \
    INSTALL_K3S_EXEC="agent --flannel-iface=tun0 --node-name=$NODE_NAME" \
    K3S_TOKEN="$K3S_TOKEN" \
    K3S_URL="$K3S_URL" \
    sh -

# Wait for k3s agent to start
echo ""
echo "Waiting for k3s agent to start..."
sleep 10

# Check service
if systemctl is-active --quiet k3s-agent; then
    echo "✓ K3s agent service is running"
else
    echo "❌ K3s agent service failed to start"
    echo "Check logs: sudo journalctl -u k3s-agent -f"
    exit 1
fi

# Display results
echo ""
echo "=========================================="
echo "  Worker Setup Complete!"
echo "=========================================="
echo ""
echo "Node Name: $NODE_NAME"
echo "Worker VPN IP: $WORKER_VPN_IP"
echo "Connected to: $K3S_URL"
echo ""
echo "✓ Worker node joined the cluster"
echo ""

echo "=========================================="
echo "  Verify from Master"
echo "=========================================="
echo ""
echo "On master node, run:"
echo "  kubectl get nodes"
echo ""
echo "You should see this worker: $NODE_NAME"
echo ""
echo "=========================================="
echo ""
