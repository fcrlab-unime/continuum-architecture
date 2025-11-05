#!/bin/bash

# === Function to start OpenVPN === 
start_vpn() {
    if [ -z "$CONFIG_FILE" ]; then
        echo "No .ovpn file found."
        exit 1
    fi

    if pgrep -f "openvpn --config $CONFIG_FILE" > /dev/null; then
        echo "VPN is already running."
    else
        sudo openvpn --config "$CONFIG_FILE" --daemon
        echo "Starting VPN..."
    fi
}

# === Function to stop OpenVPN === 
stop_vpn() {
    if pgrep -x "openvpn" > /dev/null; then
        sudo pkill -x "openvpn"
        echo "Stopping VPN."
    else
        echo "VPN is not running."
    fi
}

# === Function to start K3s node and OpenVPN === 
start_node() {
    start_vpn
    sleep 5
    if ip link show tun0 > /dev/null 2>&1; then
        if systemctl is-active --quiet k3s-agent; then
            echo "K3s node is already running."
        else
            echo "Starting K3s node..."
            sudo systemctl start k3s-agent
            if [ $? -eq 0 ]; then
                echo "K3s node started successfully!"
                VPN_DIR=$(dirname "$(readlink -f "$0")")"/src"
                CRONJOB="@reboot /bin/bash $VPN_DIR/startVpn.sh"
                if ! sudo crontab -l | grep -F "$VPN_DIR/startVpn.sh" > /dev/null; then
                    (sudo crontab -l; echo "$CRONJOB") | sudo crontab -
                fi
            else
                echo "Error starting K3s node."
            fi
        fi
    else
        echo "Error starting VPN."
    fi
}

# === Function to stop K3s node and OpenVPN === 
stop_node() {
    stop_vpn
    if systemctl is-active --quiet k3s-agent; then
        echo "Stopping K3s node..."
        sudo systemctl stop k3s-agent
        if [ $? -eq 0 ]; then
            echo "K3s node stopped successfully!"
            VPN_DIR=$(dirname "$(readlink -f "$0")")"/src"
            CRONJOB="@reboot /bin/bash $VPN_DIR/startVpn.sh"
            if sudo crontab -l | grep -F "$CRONJOB" > /dev/null; then
                sudo crontab -l | grep -v "$VPN_DIR/startVpn.sh" | sudo crontab -
            fi
        else
            echo "Error stopping K3s node."
        fi
    else
        echo "K3s node is already stopped."
    fi
}

# === Function to check the status of K3s node and OpenVPN === 
status_node() {
    local k3s_status vpn_status
    if systemctl is-active --quiet k3s-agent; then
        k3s_status="\033[0;32mactive\033[0m    |"  # Green
    else
        k3s_status="\033[0;31minactive\033[0m  |"  # Red
    fi

    if ip link show tun0 > /dev/null 2>&1; then
        vpn_status="\033[0;32mactive\033[0m    |"  # Green
    else
        vpn_status="\033[0;31minactive\033[0m  |"  # Red
    fi

    echo "+------------------------+"
    echo -e "|  K3s Status: $k3s_status"
    echo -e "|  VPN Status: $vpn_status"
    echo "+------------------------+"
}

CONFIG_FILE=$(find "$(dirname "$0")/src" -maxdepth 1 -name "*.ovpn" | head -n 1)

# === Check if the script is run as sudo === 
if [ "$(id -u)" -ne 0 ]; then
    echo
    echo "TEMA Node Management"       
    echo ""
    echo "You must run this script as sudo."
    echo ""
    exit 1
fi

# === Check if the K3s uninstall script exists === 
if [ -f "/usr/local/bin/k3s-agent-uninstall.sh" ]; then
    echo
    echo
    echo "   TEMA NODE MANAGEMENT"
    status_node
    echo

    # Management menu
    echo
    echo "Cluster Node Control"
    echo
    if systemctl is-active --quiet k3s-agent; then
        echo "1. Stop K3s node"
    else
        echo "1. Start K3s node"
    fi
    echo "2. Remove K3s node"
    echo "0. Exit"
    read -p "Choose an option: " choice
    echo

    case $choice in
        1)
            if systemctl is-active --quiet k3s-agent; then
                stop_node
            else
                start_node
            fi
            ;;
        2)
            read -p "Are you sure you want to remove this node from the TEMA cluster? Type 'remove' to proceed: " confirm
            if [ "$confirm" == "remove" ]; then
                echo "Removing node from TEMA cluster..."
                stop_node
                VPN_DIR=$(dirname "$(readlink -f "$0")")"/src"
                CRONJOB="@reboot /bin/bash $VPN_DIR/startVpn.sh"
                if sudo crontab -l | grep -F "$CRONJOB" > /dev/null; then
                    sudo crontab -l | grep -v "$VPN_DIR/startVpn.sh" | sudo crontab -
                fi
                sudo /usr/local/bin/k3s-agent-uninstall.sh
                if [ $? -eq 0 ]; then
                    echo "Node removed from TEMA cluster successfully."
                else
                    echo "Error during removal from the cluster."
                fi
            else
                echo "Removal aborted."
            fi
            ;;
        0)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid option. Exiting..."
            exit 1
            ;;
    esac
else
    sudo bash ./src/join_cluster.sh
fi