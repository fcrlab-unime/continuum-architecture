#!/bin/bash
# ============================================
#  TEMA Cluster Node Setup Script
#  Uses configuration values from .env file
# ============================================

# === Load environment variables from .env ===
if [ -f .env ]; then
    set -a
    source .env
    set +a
else
    echo "❌ .env file not found. Please create it before running this script."
    exit 1
fi

# === Validate required environment variables ===
required_vars=(
    VPN_DIR
    PARTNER_NAMES
    VPN_STATUS_URL
    VPN_GEN_CERT_URL
    VPN_USER
    VPN_PASSWORD
    K3S_URL
    K3S_TOKEN
    INSTALL_K3S_VERSION
)

for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "❌ Missing required environment variable: $var"
        exit 1
    fi
done

# === Helper Functions ===

generate_random_string() {
    head /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 5
}

get_partner_name() {
    echo
    echo "TEMA Cluster Node Setup"
    echo 
    read -p "Enter your organization name: " PARTNER_NAME
    PARTNER_NAME=$(echo "$PARTNER_NAME" | tr '[:upper:]' '[:lower:]')

    if [[ " ${PARTNER_NAMES[*]} " =~ " ${PARTNER_NAME} " ]]; then
        RANDOM_SUFFIX=$(generate_random_string)
        LABEL_NAME="${PARTNER_NAME}"
        PARTNER_NAME="${PARTNER_NAME}-${RANDOM_SUFFIX}"
    else
        echo 
        echo "Invalid name. Accepted names are:"
        echo "${PARTNER_NAMES[*]}"
        echo "------------------------------------------------------------"
        get_partner_name 
    fi
}

get_node_tier() {
    echo 
    read -p "Is this node a cloud or edge node? (Enter 'cloud' or 'edge'): " NODE_TIER
    NODE_TIER=$(echo "$NODE_TIER" | tr '[:upper:]' '[:lower:]')

    if [[ "$NODE_TIER" == "cloud" || "$NODE_TIER" == "edge" ]]; then
        label_tier="tier=$NODE_TIER"
    else
        echo ""
        echo "Invalid choice. Please enter 'cloud' or 'edge'"
        echo "------------------------------------------------------------"
        get_node_tier
    fi
}

install_package() {
    echo "Installing $1..."
    apt-get update -qq
    apt-get install -y $1
}

check_gpu() {
    echo ""
    read -p "Do you want to enable GPU support on this node? (y/n): " enable_gpu
    if [[ "$enable_gpu" =~ ^[Yy]$ ]]; then
        if command -v containerd &> /dev/null && systemctl is-active --quiet containerd; then
            if command -v nvidia-smi &> /dev/null; then
                echo "NVIDIA GPU detected..."
                cuda_version=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -n 1)
                if [[ "$cuda_version" ]]; then
                    if [ -f "/usr/bin/nvidia-container-runtime" ] || [ -f "/usr/local/bin/nvidia-container-runtime" ]; then
                        echo "Configuring NVIDIA runtime for containerd..."
                        sudo nvidia-ctk runtime configure --runtime=containerd
                        sudo systemctl restart containerd
                        echo "GPU support successfully enabled."
                    else
                        echo "NVIDIA Container Toolkit not found."
                        exit 1
                    fi
                else
                    echo "CUDA not supported on this GPU."
                    exit 1
                fi
            else
                echo "NVIDIA drivers not installed."
                exit 1
            fi
        else
            echo "Containerd service not running."
            exit 1
        fi
    else
        echo "GPU support not enabled."
    fi
}

# === Check if running as root ===
if [ "$(id -u)" -ne 0 ]; then
    echo "Please run this script as root or with sudo."
    exit 1
fi

# === Install required packages ===
for pkg in net-tools openvpn curl; do
    if ! command -v $pkg &> /dev/null; then
        echo "$pkg not found. Installing..."
        install_package $pkg
    fi
done

# === Check if K3s is already installed ===
if command -v k3s &> /dev/null; then
    echo "K3s is already installed. Exiting."
    exit 0
fi

# === Get partner name and node type ===
get_partner_name
get_node_tier

# === VPN Setup ===
EXISTING_CERT=$(find "$VPN_DIR" -maxdepth 1 -type f -name "*.ovpn" | head -n 1)

if ifconfig tun0 &> /dev/null; then
    echo "VPN is running correctly."
elif [ -n "$EXISTING_CERT" ]; then
    echo "Found existing VPN configuration: $EXISTING_CERT"
    bash "$VPN_DIR/startVpn.sh" &
    disown
    sleep 5
    if ! ifconfig tun0 &> /dev/null; then
        echo "VPN failed to start."
        exit 1
    fi
else 
    echo "Generating VPN certificate..."
    SERVICE_STATUS=$(curl -X GET "$VPN_STATUS_URL" -s)
    if [[ "$SERVICE_STATUS" != '{"status":"Service is running"}' ]]; then
        echo "VPN certificate service unavailable."
        exit 1
    fi
    mkdir -p "$VPN_DIR"
    curl -u "$VPN_USER:$VPN_PASSWORD" -X POST "$VPN_GEN_CERT_URL" -F "name=$PARTNER_NAME" -o "$VPN_DIR/$PARTNER_NAME.ovpn"
    bash "$VPN_DIR/startVpn.sh" &
    disown
    sleep 5
    if ! ifconfig tun0 &> /dev/null; then
        echo "VPN did not start correctly after certificate generation."
        exit 1
    fi
fi

# === Kubernetes (K3s) Setup ===
node_name="${PARTNER_NAME}"
label_name="partner=${LABEL_NAME}"
label_tier="tier=${NODE_TIER}"

check_gpu

echo "Installing K3s..."
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="$INSTALL_K3S_VERSION" \
INSTALL_K3S_EXEC="--flannel-iface=tun0 --node-name=$node_name --node-label=$label_tier --node-label=$label_name" \
K3S_TOKEN="$K3S_TOKEN" \
K3S_URL="$K3S_URL" sh -

# === Verify Installation ===
if [ -f "/usr/local/bin/k3s-agent-uninstall.sh" ]; then
    echo "✅ K3s installation successful."
else
    echo "❌ K3s installation failed."
    exit 1
fi
