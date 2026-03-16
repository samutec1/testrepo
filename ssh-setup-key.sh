#!/bin/bash
#
# ssh-setup-key.sh
# Connects to a remote server via SSH password (using sshpass)
# and sets up key-based authentication for future passwordless access.
#
# Usage: ./ssh-setup-key.sh <user@host> [ssh_port]

set -euo pipefail

USER_HOST="${1:-}"
SSH_PORT="${2:-22}"
KEY_FILE="$HOME/.ssh/id_ed25519"

if [ -z "$USER_HOST" ]; then
    echo "Usage: $0 <user@host> [ssh_port]"
    echo "Example: $0 admin@192.168.1.100"
    echo "Example: $0 admin@192.168.1.100 2222"
    exit 1
fi

# Check if sshpass is installed
if ! command -v sshpass &>/dev/null; then
    echo "Error: sshpass is not installed."
    echo "Install it with:"
    echo "  Debian/Ubuntu: sudo apt install sshpass"
    echo "  CentOS/RHEL:   sudo yum install sshpass"
    echo "  macOS:          brew install hudochenkov/sshpass/sshpass"
    exit 1
fi

# Step 1: Generate SSH key pair if it doesn't exist
if [ ! -f "$KEY_FILE" ]; then
    echo "[1/4] Generating SSH key pair (ed25519)..."
    ssh-keygen -t ed25519 -f "$KEY_FILE" -N "" -q
    echo "       Key generated: $KEY_FILE"
else
    echo "[1/4] SSH key already exists: $KEY_FILE"
fi

# Step 2: Read password securely
echo -n "[2/4] Enter SSH password for $USER_HOST: "
read -rs SSH_PASS
echo

if [ -z "$SSH_PASS" ]; then
    echo "Error: Password cannot be empty."
    exit 1
fi

# Step 3: Copy public key to remote server using sshpass
echo "[3/4] Copying public key to $USER_HOST..."
sshpass -p "$SSH_PASS" ssh-copy-id \
    -i "$KEY_FILE.pub" \
    -p "$SSH_PORT" \
    -o StrictHostKeyChecking=accept-new \
    "$USER_HOST"

# Step 4: Verify key-based authentication works
echo "[4/4] Verifying key-based authentication..."
if ssh -i "$KEY_FILE" -p "$SSH_PORT" -o BatchMode=yes "$USER_HOST" "echo 'OK'" &>/dev/null; then
    echo ""
    echo "Success! Key-based authentication is configured."
    echo "You can now connect without a password:"
    echo "  ssh $USER_HOST"
    echo ""
    echo "To disable password authentication on the server (recommended):"
    echo "  ssh $USER_HOST \"sudo sed -i 's/^#\\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config && sudo systemctl restart sshd\""
else
    echo ""
    echo "Warning: Key was copied but verification failed."
    echo "Try connecting manually: ssh -i $KEY_FILE -p $SSH_PORT $USER_HOST"
    exit 1
fi
