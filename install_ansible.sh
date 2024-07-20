#!/bin/bash

set -e

# Function to check and install dependencies on macOS
install_on_macos() {
    echo "Checking for Homebrew..."
    if ! command -v brew &>/dev/null; then
        echo "Homebrew not found. Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    else
        echo "Homebrew is already installed."
    fi

    echo "Updating Homebrew..."
    brew update

    echo "Installing Ansible..."
    brew install ansible
}

# Function to check and install dependencies on Debian-based Linux
install_on_debian() {
    echo "Updating package list..."
    sudo apt-get update

    echo "Installing dependencies..."
    sudo apt-get install -y software-properties-common

    echo "Adding Ansible PPA..."
    sudo apt-add-repository --yes --update ppa:ansible/ansible

    echo "Installing Ansible..."
    sudo apt-get install -y ansible
}

# Function to check and install dependencies on RedHat-based Linux
install_on_redhat() {
    echo "Installing EPEL repository..."
    sudo yum install -y epel-release

    echo "Installing Ansible..."
    sudo yum install -y ansible
}

# Main script execution
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "Detected macOS."
    install_on_macos
elif [[ -f /etc/debian_version ]]; then
    echo "Detected Debian-based Linux."
    install_on_debian
elif [[ -f /etc/redhat-release ]]; then
    echo "Detected RedHat-based Linux."
    install_on_redhat
else
    echo "Unsupported OS type: $OSTYPE"
    exit 1
fi

echo "Ansible installation complete!"
