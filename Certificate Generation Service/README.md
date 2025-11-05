# Certificate Generation Service

A FastAPI-based web service for automated OpenVPN certificate distribution with HTTP Basic Authentication. The service assigns VPN certificates (`.ovpn` files) to users on-demand from a pool of available certificates.

## Features

- 🔒 HTTP Basic Authentication
- 📁 Automatic certificate assignment from source pool
- 🔄 Certificate tracking (moved from source to assigned directory)
- 🚀 FastAPI with automatic API documentation
- ⚙️ Environment-based configuration
- 📊 Service health check endpoint
- 🔐 OpenVPN certificate management

## What This Service Does

This service acts as a **certificate distribution server** for OpenVPN. It:

1. Stores a pool of pre-generated OpenVPN certificates (`.ovpn` files)
2. Distributes them to users/nodes on request via HTTP API
3. Tracks which certificates have been assigned
4. Prevents certificate reuse by moving assigned certificates to a separate directory

**Use Case:** Perfect for automatically distributing VPN certificates to new nodes joining your infrastructure (e.g., k3s cluster nodes, edge devices, remote workers).

---

## Prerequisites

### Server Requirements

- **Python 3.8+**
- **pip** (Python package manager)
- **Operating System:** Linux (Ubuntu, Debian, CentOS, RHEL)

### OpenVPN Certificates

- You need **pre-generated OpenVPN certificates** (`.ovpn` files)
- These certificates must be generated from your OpenVPN server
- Each certificate file should be a complete OpenVPN configuration file

**Where to get certificates:**
- Generate them from your OpenVPN server using `easy-rsa` or similar tools
- Export them as `.ovpn` files (unified format)
- Each certificate should be unique and ready to use

---

## Installation

### 1. Clone or Download the Project

```bash
cd ~
git clone <repo-url> cert-gen-service
cd cert-gen-service
```

### 2. Install Dependencies

```bash
pip install -r requirements.txt
```

Or create a virtual environment (recommended):

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### 3. Set Up Configuration

```bash
cp example.env .env
nano .env
```

Edit `.env` with your actual values:
```bash
CERTS_DIR="/path/to/cert"                    # Where source certificates are stored
ASSIGNED_CERTS_DIR="/path/to/cert-assigned"  # Where assigned certificates go
AUTH_USERNAME="admin"                        # API authentication username
AUTH_PASSWORD="SecureP@ssw0rd!"              # API authentication password
FLASK_HOST="0.0.0.0"                         # Bind to all interfaces
FLASK_PORT="8000"                            # Service port
```

---

## Directory Structure

Create the following directory structure:

```
cert-gen-service/
├── cert-gen.py           # Main application
├── requirements.txt      # Python dependencies
├── .env                  # Configuration (create from .env.example)
├── example.env           # Configuration template
├── README.md             # This file
├── cert/                 # Source certificates directory
│   ├── cert001.ovpn      # OpenVPN certificate 1
│   ├── cert002.ovpn      # OpenVPN certificate 2
│   └── cert003.ovpn      # OpenVPN certificate 3
└── cert-assigned/        # Assigned certificates directory
    └── (assigned certificates will be stored here)
```

---

## Certificate Setup

### 1. Create Directories

```bash
mkdir -p cert cert-assigned
```

### 2. Generate or Place OpenVPN Certificates

**Option A: Generate certificates from your OpenVPN server**

```bash
# On your OpenVPN server with easy-rsa
cd /path/to/easy-rsa
./easyrsa build-client-full client001 nopass
./easyrsa build-client-full client002 nopass
# ... generate more as needed

# Export as .ovpn files and copy to cert/ directory
cp client001.ovpn /path/to/cert-gen-service/cert/
cp client002.ovpn /path/to/cert-gen-service/cert/
```

**Option B: Copy existing certificates**

```bash
# Copy your existing OpenVPN .ovpn files
cp /path/to/your/certificates/*.ovpn ./cert/
```

### 3. Set Directory Permissions

```bash
chmod 755 cert cert-assigned
chmod 644 cert/*.ovpn
```

**Important Notes:**
- Certificates will be assigned in **alphabetical order**
- Once assigned, certificates are **permanently moved** from `cert/` to `cert-assigned/`
- The service needs **read/write permissions** on both directories
- Make sure each `.ovpn` file is a complete, working OpenVPN configuration

---

## Configuration

Edit the `.env` file with your settings:

| Variable | Description | Example |
|----------|-------------|---------|
| `CERTS_DIR` | Source certificates directory (absolute path) | `/home/user/cert-gen/cert` |
| `ASSIGNED_CERTS_DIR` | Assigned certificates directory (absolute path) | `/home/user/cert-gen/cert-assigned` |
| `AUTH_USERNAME` | HTTP Basic Auth username | `admin` |
| `AUTH_PASSWORD` | HTTP Basic Auth password | `SecureP@ssw0rd!` |
| `FLASK_HOST` | Server bind address | `0.0.0.0` (all interfaces) or `127.0.0.1` (localhost) |
| `FLASK_PORT` | Server port | `8000` |

---

## Running the Service

### Development Mode

```bash
python cert-gen.py
```

### Production Mode with Uvicorn

```bash
uvicorn cert-gen:app --host 0.0.0.0 --port 8000
```

### With Automatic Reload (Development)

```bash
uvicorn cert-gen:app --host 0.0.0.0 --port 8000 --reload
```

### As a Background Service

```bash
nohup uvicorn cert-gen:app --host 0.0.0.0 --port 8000 > service.log 2>&1 &
```

---

## API Endpoints

### 1. Health Check

**GET** `/status`

Check if the service is running.

**Example:**
```bash
curl http://localhost:8000/status
```

**Response:**
```json
{
  "status": "Service is running"
}
```

---

### 2. Generate/Assign Certificate

**POST** `/gen-cert`

Request an OpenVPN certificate assignment. Requires HTTP Basic Authentication.

**Parameters:**
- `name` (form data, required): Client identifier (used for naming the assigned certificate)

**Example:**
```bash
curl -X POST http://localhost:8000/gen-cert \
  -u admin:SecureP@ssw0rd! \
  -F "name=client_001" \
  --output client_001.ovpn
```

**What happens:**
1. Service validates your credentials
2. Picks the first available certificate from `cert/` directory (alphabetically)
3. Copies it to `cert-assigned/` with name: `client_001_cert001.ovpn`
4. Deletes the original from `cert/` directory
5. Returns the certificate file as `client_001.ovpn` for download

**Response:**
- **Success (200):** Returns the `.ovpn` file for download
- **Error (400):** Missing `name` parameter
- **Error (404):** No certificates available in the pool
- **Error (500):** Internal server error (permissions, file access, etc.)

---

## API Documentation

FastAPI provides automatic interactive documentation:

- **Swagger UI:** http://localhost:8000/docs
- **ReDoc:** http://localhost:8000/redoc

Use these to test the API directly from your browser!

---

## How It Works

### Certificate Distribution Flow

```
1. Client Request
   ↓
   POST /gen-cert with name="node-01"
   ↓
2. Authentication
   ↓
   HTTP Basic Auth validated
   ↓
3. Certificate Selection
   ↓
   Pick first .ovpn from cert/ (alphabetically)
   ↓
4. Assignment
   ↓
   Copy to cert-assigned/ as node-01_cert001.ovpn
   Delete from cert/
   ↓
5. Response
   ↓
   Return .ovpn file as node-01.ovpn
```

### Example Workflow

**Initial State:**
```bash
$ ls cert/
cert001.ovpn  cert002.ovpn  cert003.ovpn

$ ls cert-assigned/
# (empty)
```

**Client 1 requests a certificate:**
```bash
$ curl -X POST http://localhost:8000/gen-cert \
  -u admin:password \
  -F "name=client1" \
  --output client1.ovpn

# Downloads client1.ovpn
```

**After first request:**
```bash
$ ls cert/
cert002.ovpn  cert003.ovpn

$ ls cert-assigned/
client1_cert001.ovpn
```

**Client 2 requests a certificate:**
```bash
$ curl -X POST http://localhost:8000/gen-cert \
  -u admin:password \
  -F "name=client2" \
  --output client2.ovpn
```

**After second request:**
```bash
$ ls cert/
cert003.ovpn

$ ls cert-assigned/
client1_cert001.ovpn
client2_cert002.ovpn
```

---

## Integration with k3s Cluster Setup

This service is designed to work with automated cluster node setup scripts. When a new node joins:

1. Node setup script calls this API
2. Downloads a unique OpenVPN certificate
3. Uses the certificate to connect to VPN (tun0)
4. Joins the k3s cluster over VPN

**Example integration in setup script:**
```bash
# Get VPN certificate
curl -X POST http://vpn-server:8000/gen-cert \
  -u $VPN_USER:$VPN_PASSWORD \
  -F "name=$NODE_NAME" \
  --output /etc/openvpn/client.ovpn

# Connect to VPN
sudo openvpn --config /etc/openvpn/client.ovpn --daemon

# Wait for VPN connection
sleep 5

# Continue with k3s setup...
```

---

## Troubleshooting

### Service Won't Start

**Problem:** Service fails to start

**Solutions:**
```bash
# 1. Check if .env file exists
ls -la .env

# 2. Verify Python dependencies
pip install -r requirements.txt

# 3. Check if port is already in use
sudo lsof -i :8000

# 4. Check Python version
python --version  # Should be 3.8+

# 5. Check logs
python cert-gen.py  # Run in foreground to see errors
```

---

### Certificate Not Found Error

**Problem:** API returns 404 "No certificates available"

**Solutions:**
```bash
# 1. Verify certificates exist in CERTS_DIR
ls -la cert/

# 2. Check that files are .ovpn format
ls cert/*.ovpn

# 3. Verify directory path in .env
cat .env | grep CERTS_DIR

# 4. Check permissions
ls -ld cert/
# Should show: drwxr-xr-x (755)

ls -l cert/*.ovpn
# Should show: -rw-r--r-- (644)
```

---

### Authentication Fails

**Problem:** API returns 401 Unauthorized

**Solutions:**
```bash
# 1. Verify credentials in .env
cat .env | grep AUTH_

# 2. Check credentials in curl command match .env
# Example: -u admin:password

# 3. Test with curl verbose mode
curl -v -X POST http://localhost:8000/gen-cert \
  -u admin:password \
  -F "name=test"
```

---

### Permission Denied Errors

**Problem:** Service can't read/write certificates

**Solutions:**
```bash
# Fix directory permissions
sudo chmod 755 cert cert-assigned

# Fix file permissions
sudo chmod 644 cert/*.ovpn

# Check ownership
ls -ld cert cert-assigned
# Should be owned by user running the service

# If needed, change ownership
sudo chown -R your-username:your-username cert cert-assigned
```

---

### Certificate File Corruption

**Problem:** Downloaded .ovpn file doesn't work

**Solutions:**
```bash
# 1. Verify source certificate is valid
cat cert/cert001.ovpn  # Should show valid OpenVPN config

# 2. Test certificate manually
sudo openvpn --config cert/cert001.ovpn

# 3. Check file size after download
ls -lh downloaded.ovpn
# Should match original size

# 4. Verify content
head -20 downloaded.ovpn
# Should start with: client, dev tun, proto udp, etc.
```

---

## Security Recommendations

### 1. Use Strong Passwords

```bash
# Generate a strong password
openssl rand -base64 32

# Set in .env
AUTH_PASSWORD="<generated-password>"
```

### 2. Use HTTPS in Production

Use a reverse proxy (nginx, Caddy, Apache) with SSL/TLS:

**nginx example:**
```nginx
server {
    listen 443 ssl;
    server_name vpn-certs.example.com;
    
    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;
    
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### 3. Restrict Access with Firewall

```bash
# Only allow specific IPs
sudo ufw allow from 192.168.1.0/24 to any port 8000
sudo ufw enable
```

### 4. Protect Configuration Files

```bash
# Protect .env
chmod 600 .env

# Add to .gitignore
echo ".env" >> .gitignore
echo "cert/*.ovpn" >> .gitignore
echo "cert-assigned/*.ovpn" >> .gitignore
```

### 5. Monitor Certificate Pool

```bash
# Check remaining certificates
ls cert/*.ovpn | wc -l

# Set up alert when running low
if [ $(ls cert/*.ovpn 2>/dev/null | wc -l) -lt 5 ]; then
    echo "Warning: Less than 5 certificates remaining!"
fi
```

### 6. Regular Backups

```bash
# Backup assigned certificates tracking
tar -czf cert-assigned-backup-$(date +%Y%m%d).tar.gz cert-assigned/
```

---

## systemd Service (Optional)

For production deployment, run as a systemd service.

**Create service file:** `/etc/systemd/system/cert-gen.service`

```ini
[Unit]
Description=OpenVPN Certificate Generation Service
After=network.target

[Service]
Type=simple
User=your_user
Group=your_group
WorkingDirectory=/path/to/cert-gen-service
Environment="PATH=/path/to/venv/bin"
ExecStart=/path/to/venv/bin/uvicorn cert-gen:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

**Enable and start:**
```bash
sudo systemctl daemon-reload
sudo systemctl enable cert-gen
sudo systemctl start cert-gen
sudo systemctl status cert-gen
```

**View logs:**
```bash
sudo journalctl -u cert-gen -f
```

---

## Production Deployment Checklist

- [ ] Use strong authentication credentials
- [ ] Enable HTTPS (reverse proxy with SSL)
- [ ] Configure firewall rules
- [ ] Set up systemd service
- [ ] Configure log rotation
- [ ] Set up monitoring/alerts for certificate pool
- [ ] Regular backups of cert-assigned/ directory
- [ ] Document certificate generation process
- [ ] Test certificate distribution flow
- [ ] Set up certificate pool refill procedure

---

## Monitoring and Maintenance

### Check Service Status

```bash
# If running as systemd service
sudo systemctl status cert-gen

# If running manually
ps aux | grep uvicorn
```

### Check Logs

```bash
# systemd logs
sudo journalctl -u cert-gen -f

# Manual logs
tail -f service.log
```

### Monitor Certificate Pool

```bash
# Count remaining certificates
echo "Remaining certificates: $(ls cert/*.ovpn 2>/dev/null | wc -l)"

# List assigned certificates
ls -lh cert-assigned/
```

### Refill Certificate Pool

When running low on certificates:

1. Generate new certificates on OpenVPN server
2. Export as `.ovpn` files
3. Copy to `cert/` directory
4. Set correct permissions

```bash
# Example
scp openvpn-server:/path/to/new-certs/*.ovpn cert/
chmod 644 cert/*.ovpn
```

---
