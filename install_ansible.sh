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

# Fix zsh directory permissions that cause brew doctor warnings
fix_zsh_permissions() {
    local zsh_dirs=("/usr/local/share/zsh" "/usr/local/share/zsh/site-functions")
    for dir in "${zsh_dirs[@]}"; do
        if [[ -d "$dir" ]] && [[ ! -w "$dir" ]]; then
            info "Fixing permissions on $dir..."
            sudo chmod g-w "$dir"
            sudo chown "$(whoami)" "$dir"
        fi
    done
}

# Function to check and install dependencies on macOS
install_on_macos() {
    info "Checking for Homebrew..."
    if ! command -v brew &>/dev/null; then
        info "Homebrew not found. Installing..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        # Homebrew installer prints eval instructions; ensure brew is in PATH
        if [[ -x "/opt/homebrew/bin/brew" ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [[ -x "/usr/local/bin/brew" ]]; then
            eval "$(/usr/local/bin/brew shellenv)"
        fi
    else
        info "Homebrew is already installed."
    fi

    # Derive paths from the actual Homebrew installation
    local homebrew_prefix=$(brew --prefix)
    local mas_path="$homebrew_prefix/bin/mas"
    info "Homebrew prefix: $homebrew_prefix"

    info "Updating Homebrew..."
    brew update

    # Fix zsh directory permissions that Homebrew operations can leave misconfigured
    fix_zsh_permissions

    # GitHub CLI and 1Password CLI: needed before the dotfiles clone (see authenticate_github)
    if ! command -v gh &>/dev/null; then
        info "Installing GitHub CLI..."
        brew install gh
    else
        info "GitHub CLI is already installed."
    fi
    if ! command -v op &>/dev/null; then
        info "Installing 1Password CLI..."
        brew install 1password-cli
    else
        info "1Password CLI is already installed."
    fi

    info "Installing Ansible..."
    brew install ansible

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
    ansible-galaxy install --force git+https://github.com/getfatday/ansible-role-dotmodules.git

    # Accept Xcode license if needed (for MAS apps)
    # Only attempt if full Xcode is installed (not just Command Line Tools)
    if [[ -d "/Applications/Xcode.app" ]] && command -v xcodebuild &>/dev/null; then
        if ! xcodebuild -license check &>/dev/null; then
            warning "Xcode license needs to be accepted for Mac App Store apps..."
            info "Accepting Xcode license..."
            sudo xcodebuild -license accept
        else
            info "Xcode license already accepted."
        fi
    else
        info "Xcode not installed (Command Line Tools only) — skipping license check."
        info "Install Xcode from the App Store if you need Mac App Store app management."
    fi

    # Export paths for downstream use
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

        local homebrew_prefix=$(brew --prefix)
        local mas_path="$homebrew_prefix/bin/mas"

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
    mas_path: "$mas_path"
  roles:
    - ansible-role-dotmodules
EOF

        success "Sample playbook created: sample-dotfiles.yml"
        info "MAS path configured: $mas_path"
        info "To use: ansible-playbook -i localhost, sample-dotfiles.yml"
    fi
}

# Authenticate gh so the dotfiles clone works whether the repo is public or private.
# Three paths, first match wins:
#   1. DOTFILES_BOOTSTRAP_TOKEN set (unattended): a fine-grained read-only GitHub
#      token injected by a VM or Pi bootstrap, fed to `gh auth login --with-token`.
#   2. OP_SERVICE_ACCOUNT_TOKEN set (unattended): the GitHub token is read from the
#      1Password item at DOTFILES_BOOTSTRAP_OP_REF (default
#      "op://Private/GitHub getfatday/token") with `op read`.
#   3. Otherwise (interactive): `gh auth login --web` unless gh is already logged in
#      as DOTFILES_GH_USER (default getfatday).
# Every path ends with `gh auth setup-git`, which makes git use gh as the credential
# helper for github.com. Skipped with a warning when gh is not installed.
authenticate_github() {
    local gh_user="${DOTFILES_GH_USER:-getfatday}"
    local op_ref="${DOTFILES_BOOTSTRAP_OP_REF:-op://Private/GitHub getfatday/token}"

    if ! command -v gh &>/dev/null; then
        warning "GitHub CLI not found — skipping GitHub authentication."
        return 0
    fi

    if [[ -n "${DOTFILES_BOOTSTRAP_TOKEN:-}" ]]; then
        info "Authenticating GitHub CLI with DOTFILES_BOOTSTRAP_TOKEN..."
        printf '%s\n' "$DOTFILES_BOOTSTRAP_TOKEN" | gh auth login --hostname github.com --with-token
    elif [[ -n "${OP_SERVICE_ACCOUNT_TOKEN:-}" ]]; then
        if ! command -v op &>/dev/null; then
            warning "OP_SERVICE_ACCOUNT_TOKEN is set but the 1Password CLI is not installed."
            exit 1
        fi
        info "Authenticating GitHub CLI with the token at $op_ref..."
        op read "$op_ref" | gh auth login --hostname github.com --with-token
    elif [[ "$(gh api user --jq .login 2>/dev/null)" == "$gh_user" ]]; then
        info "GitHub CLI is already logged in as $gh_user."
    else
        info "Logging in to GitHub as $gh_user (opens a browser)..."
        gh auth login --hostname github.com --web --git-protocol https
    fi

    gh auth setup-git --hostname github.com
}

# Clone and deploy dotfiles if DOTFILES_REPO is set or use default
deploy_dotfiles() {
    local dotfiles_owner="${DOTFILES_GH_USER:-getfatday}"
    local dotfiles_repo="${DOTFILES_REPO:-https://github.com/$dotfiles_owner/dotfiles.git}"
    local dotfiles_dir="${DOTFILES_DIR:-$HOME/src/dotfiles}"

    if git -C "$dotfiles_dir" rev-parse --is-inside-work-tree &>/dev/null; then
        info "Dotfiles already cloned at $dotfiles_dir — pulling latest..."
        git -C "$dotfiles_dir" pull
    elif [[ -e "$dotfiles_dir" ]]; then
        warning "$dotfiles_dir exists but is not a git repository — refusing to clone over it."
        exit 1
    else
        mkdir -p "$(dirname "$dotfiles_dir")"
        if command -v gh &>/dev/null && [[ -z "${DOTFILES_REPO:-}" ]]; then
            info "Cloning $dotfiles_owner/dotfiles with GitHub CLI..."
            gh repo clone "$dotfiles_owner/dotfiles" "$dotfiles_dir"
        else
            info "Cloning dotfiles from $dotfiles_repo..."
            git clone "$dotfiles_repo" "$dotfiles_dir"
        fi
    fi

    # Install requirements if requirements.yml exists
    if [[ -f "$dotfiles_dir/requirements.yml" ]]; then
        info "Installing requirements from requirements.yml..."
        ansible-galaxy install --force -r "$dotfiles_dir/requirements.yml"
    fi

    # Run the playbook
    if [[ -f "$dotfiles_dir/playbooks/deploy.yml" ]]; then
        info "Running dotfiles deployment..."
        ansible-playbook "$dotfiles_dir/playbooks/deploy.yml" \
            -i "$dotfiles_dir/playbooks/inventory" \
            --ask-become-pass --diff
    else
        warning "No playbooks/deploy.yml found in $dotfiles_dir"
        info "Create a playbook or run manually."
    fi
}

# Create sample playbook (for reference)
create_sample_playbook

success "Ansible installation complete!"

# Authenticate to GitHub, then deploy dotfiles
authenticate_github
deploy_dotfiles

success "Bootstrap complete!"
