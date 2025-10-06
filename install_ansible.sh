#!/bin/bash

set -e

# Define the info function to echo text in lilac color
info() {
    echo -e "\033[1;35m$1\033[0m"
}

# Define the success function to echo text in green color
success() {
    echo -e "\033[1;32m$1\033[0m"
}

# Define the warning function to echo text in yellow color
warning() {
    echo -e "\033[1;33m$1\033[0m"
}

# Function to detect architecture and Homebrew installation mode
detect_homebrew_architecture() {
    local arch_type=$(arch)
    local uname_m=$(uname -m)
    
    info "Detecting system architecture..."
    info "arch command: $arch_type"
    info "uname -m: $uname_m"
    
    # Check if running under Rosetta 2 (x86_64 emulation on ARM64)
    if [[ "$arch_type" == "i386" ]] && [[ "$uname_m" == "x86_64" ]]; then
        info "Detected Rosetta 2 emulation (x86_64 on ARM64)"
        echo "x86_64"
    elif [[ "$arch_type" == "arm64" ]] && [[ "$uname_m" == "arm64" ]]; then
        info "Detected native ARM64"
        echo "arm64"
    elif [[ "$uname_m" == "x86_64" ]]; then
        info "Detected Intel x86_64"
        echo "x86_64"
    else
        warning "Unknown architecture: arch=$arch_type, uname=$uname_m"
        echo "x86_64"  # Default to x86_64 for compatibility
    fi
}

# Function to check and install dependencies on macOS
install_on_macos() {
    local homebrew_arch=$(detect_homebrew_architecture)
    local homebrew_prefix="/usr/local"
    local mas_path="/usr/local/bin/mas"
    
    if [[ "$homebrew_arch" == "arm64" ]]; then
        homebrew_prefix="/opt/homebrew"
        mas_path="/opt/homebrew/bin/mas"
        info "Using ARM64 Homebrew installation..."
    else
        info "Using x86_64 Homebrew installation..."
    fi
    
    info "Checking for Homebrew..."
    if ! command -v brew &>/dev/null; then
        info "Homebrew not found. Installing Homebrew for $homebrew_arch..."
        if [[ "$homebrew_arch" == "arm64" ]]; then
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        else
            # Force x86_64 installation even on ARM64 Macs (Rosetta 2)
            arch -x86_64 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
    else
        info "Homebrew is already installed."
        # Verify the installation is correct for the detected architecture
        local current_prefix=$(brew --prefix)
        if [[ "$current_prefix" != "$homebrew_prefix" ]]; then
            warning "Homebrew architecture mismatch detected!"
            warning "Expected: $homebrew_prefix, Found: $current_prefix"
            warning "This may cause issues. Consider reinstalling Homebrew for the correct architecture."
        fi
    fi

    info "Updating Homebrew..."
    brew update

    info "Checking for Python3..."
    if ! command -v python3 &>/dev/null; then
        info "Python3 not found. Installing Python3..."
        brew install python
    else
        info "Python3 is already installed."
    fi

    info "Checking for pip3..."
    if ! command -v pip3 &>/dev/null; then
        info "pip3 not found. Installing pip3..."
        brew install python
    else
        info "pip3 is already installed."
    fi

    info "Installing Ansible using pip3..."
    pip3 install ansible

    # ansible-role-dotmodules specific setup
    info "Setting up ansible-role-dotmodules dependencies..."
    
    # Install GNU Stow if missing
    if ! command -v stow &>/dev/null; then
        info "Installing GNU Stow..."
        brew install stow
    else
        info "GNU Stow is already installed."
    fi

    # Install required Ansible collections
    info "Installing required Ansible collections..."
    ansible-galaxy collection install geerlingguy.mac

    # Accept Xcode license if needed (for MAS apps)
    if command -v xcodebuild &>/dev/null; then
        if ! xcodebuild -license check &>/dev/null; then
            warning "Xcode license needs to be accepted for Mac App Store apps..."
            info "Accepting Xcode license..."
            sudo xcodebuild -license accept
        else
            info "Xcode license already accepted."
        fi
    fi

    # Set up Homebrew path detection based on architecture
    info "Configuring Homebrew paths for $homebrew_arch architecture..."
    export MAS_PATH="$mas_path"
    export HOMEBREW_PREFIX="$homebrew_prefix"
    success "Homebrew paths configured: MAS_PATH=$mas_path, HOMEBREW_PREFIX=$homebrew_prefix"
}

# Function to check and install dependencies on Debian-based Linux
install_on_debian() {
    info "Updating package list..."
    sudo apt-get update

    info "Installing Python3 and pip3..."
    sudo apt-get install -y python3 python3-pip

    info "Installing Ansible using apt..."
    sudo apt install ansible -y
}

# Function to check and install dependencies on RedHat-based Linux
install_on_redhat() {
    info "Updating package list..."
    sudo yum update -y

    info "Installing Python3 and pip3..."
    sudo yum install -y python3 python3-pip

    info "Installing Ansible using yum..."
    sudo yum install ansible -y
}

# Main script execution
if [[ "$OSTYPE" == "darwin"* ]]; then
    info "Detected macOS."
    install_on_macos
elif [[ -f /etc/debian_version ]]; then
    info "Detected Debian-based Linux."
    install_on_debian
elif [[ -f /etc/redhat-release ]]; then
    info "Detected RedHat-based Linux."
    install_on_redhat
else
    info "Unsupported OS type: $OSTYPE"
    exit 1
fi

# Function to create a sample ansible-role-dotmodules playbook
create_sample_playbook() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        info "Creating sample ansible-role-dotmodules playbook..."
        
        # Detect current architecture for the sample
        local current_arch=$(detect_homebrew_architecture)
        local mas_path="/usr/local/bin/mas"
        
        if [[ "$current_arch" == "arm64" ]]; then
            mas_path="/opt/homebrew/bin/mas"
        fi
        
        cat > sample-dotfiles.yml << EOF
---
# Sample ansible-role-dotmodules playbook
- name: Deploy dotfiles using ansible-role-dotmodules
  hosts: localhost
  vars:
    dotmodules:
      repo: "file://{{ playbook_dir }}/../modules"
      dest: "{{ ansible_env.HOME }}/.dotmodules"
      install:
        - shell
        - git
        - editor
    # Configure MAS path for detected architecture ($current_arch)
    mas_path: "$mas_path"
  roles:
    - ansible-role-dotmodules
EOF

        success "Sample playbook created: sample-dotfiles.yml"
        info "Architecture detected: $current_arch"
        info "MAS path configured: $mas_path"
        info "To use: ansible-playbook -i localhost, sample-dotfiles.yml"
    fi
}

# Create sample playbook
create_sample_playbook

success "Ansible installation complete!"
info "Next steps:"
info "1. Install the ansible-role-dotmodules role:"
info "   ansible-galaxy install git+https://github.com/getfatday/ansible-role-dotmodules.git"
info "2. Create your dotfiles modules in a 'modules/' directory"
info "3. Run your playbook: ansible-playbook -i localhost, sample-dotfiles.yml"
