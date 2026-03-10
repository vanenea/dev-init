#!/usr/bin/env bash

set -e

################################
# Color output
################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

################################
# Helper functions
################################

check_cmd() {
    command -v "$1" >/dev/null 2>&1
}

# Check if whiptail is available, fallback to dialog
check_dialog_tool() {
    if check_cmd whiptail; then
        echo "whiptail"
    elif check_cmd dialog; then
        echo "dialog"
    else
        echo "none"
    fi
}

# Safe download: download to temp file, check exit code
safe_download() {
    local url="$1"
    local output="$2"

    log_info "Downloading: $url"

    if ! curl -fsSL "$url" -o "$output"; then
        log_error "Failed to download: $url"
        rm -f "$output"
        return 1
    fi

    if [ ! -s "$output" ]; then
        log_error "Downloaded file is empty: $url"
        rm -f "$output"
        return 1
    fi

    log_info "Download completed successfully"
    return 0
}

# Execute script file safely
safe_execute() {
    local script_file="$1"
    local description="$2"

    log_info "Executing $description..."

    if ! bash "$script_file"; then
        log_error "Failed to execute $description"
        return 1
    fi

    log_info "$description completed successfully"
    return 0
}

# Get latest NVM version
get_latest_nvm_version() {
    local version
    version=$(curl -fsSL https://api.github.com/repos/nvm-sh/nvm/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')

    if [ -z "$version" ]; then
        log_warn "Failed to get latest NVM version, using fallback v0.40.0"
        echo "v0.40.0"
    else
        echo "$version"
    fi
}

################################
# Check dialog tool
################################

DIALOG_TOOL=$(check_dialog_tool)

if [ "$DIALOG_TOOL" = "none" ]; then
    log_error "Neither whiptail nor dialog is installed. Please install one of them:"
    echo "  sudo apt install -y whiptail"
    echo "  OR"
    echo "  sudo sudo apt install -y dialog"
    exit 1
fi

log_info "Using dialog tool: $DIALOG_TOOL"

################################
# Install dependency if needed
################################

if ! check_cmd whiptail; then
    log_info "Installing whiptail..."
    sudo apt update
    sudo apt install -y whiptail
fi

################################
# Choose components
################################

CHOICES=$($DIALOG_TOOL --title "Dev Environment Setup" \
--checklist "Select components to install" 20 60 10 \
"git" "Git" ON \
"java" "OpenJDK" ON \
"maven" "Maven" OFF \
"node" "Node.js (via NVM)" ON \
"uv" "Python uv" OFF \
"docker" "Docker" OFF \
3>&1 1>&2 2>&3)

# Check if user canceled
exit_code=$?
if [ $exit_code -ne 0 ]; then
    log_info "Installation canceled by user"
    exit 0
fi

clear

# Check if nothing selected
if [ -z "$CHOICES" ]; then
    log_warn "No components selected. Exiting."
    exit 0
fi

################################
# Version selection
################################

JAVA_VERSION=17
NODE_VERSION=lts

if [[ $CHOICES == *"java"* ]]; then
    JAVA_VERSION=$($DIALOG_TOOL --title "Java Version" \
    --menu "Select JDK version" 15 60 4 \
    17 "LTS" \
    21 "LTS" \
    11 "Legacy" \
    3>&1 1>&2 2>&3)

    if [ $? -ne 0 ]; then
        log_warn "Java version selection canceled, using default: 17"
        JAVA_VERSION=17
    fi
fi

if [[ $CHOICES == *"node"* ]]; then
    NODE_VERSION=$($DIALOG_TOOL --title "Node Version" \
    --menu "Select Node version" 15 60 4 \
    lts "Latest LTS" \
    22 "Node 22" \
    20 "Node 20" \
    18 "Node 18" \
    3>&1 1>&2 2>&3)

    if [ $? -ne 0 ]; then
        log_warn "Node version selection canceled, using default: lts"
        NODE_VERSION=lts
    fi
fi

################################
# Summary and confirm
################################

SUMMARY="You selected:\n\n"

for c in $CHOICES
do
    c=$(echo $c | tr -d '"')
    SUMMARY+="✔ $c\n"
done

if [[ $CHOICES == *"java"* ]]; then
    SUMMARY+="  → Java version: $JAVA_VERSION\n"
fi

if [[ $CHOICES == *"node"* ]]; then
    SUMMARY+="  → Node version: $NODE_VERSION\n"
fi

SUMMARY+="\nContinue installation?"

$DIALOG_TOOL --title "Confirm Installation" \
--yesno "$SUMMARY" 20 60

if [ $? -ne 0 ]; then
    log_info "Installation canceled by user"
    exit 0
fi

clear

################################
# Install functions
################################

install_git() {
    if check_cmd git; then
        local version=$(git --version)
        log_info "Git already installed: $version"
    else
        log_info "Installing git..."
        sudo apt install -y git
    fi
}

install_java() {
    if check_cmd java; then
        local current_version=$(java -version 2>&1 | head -n 1 | cut -d'"' -f2)
        local target_version="1.$JAVA_VERSION"

        if [[ "$current_version" == *"1.$JAVA_VERSION"* ]] || [[ "$current_version" == *"$JAVA_VERSION"* ]]; then
            log_info "Java $JAVA_VERSION already installed: $current_version"
        else
            log_warn "Current Java version: $current_version"
            log_info "Installing OpenJDK $JAVA_VERSION..."
            sudo apt install -y openjdk-${JAVA_VERSION}-jdk
            sudo update-alternatives --set java /usr/lib/jvm/java-${JAVA_VERSION}-openjdk-amd64/bin/java
        fi
    else
        log_info "Installing OpenJDK $JAVA_VERSION..."
        sudo apt install -y openjdk-${JAVA_VERSION}-jdk
    fi
}

install_maven() {
    if check_cmd mvn; then
        local version=$(mvn --version | head -n 1)
        log_info "Maven already installed: $version"
    else
        log_info "Installing maven..."
        sudo apt install -y maven
    fi
}

install_node() {
    export NVM_DIR="$HOME/.nvm"

    # Create NVM directory if not exists
    if [ ! -d "$NVM_DIR" ]; then
        log_info "Installing NVM..."

        local nvm_version=$(get_latest_nvm_version)
        local nvm_url="https://raw.githubusercontent.com/nvm-sh/nvm/${nvm_version}/install.sh"
        local temp_file=$(mktemp)

        if safe_download "$nvm_url" "$temp_file"; then
            safe_execute "$temp_file" "NVM installer"
            rm -f "$temp_file"
        else
            log_error "Failed to install NVM"
            return 1
        fi
    else
        log_info "NVM already installed"
    fi

    # Source NVM
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

    # Install Node
    if check_cmd node; then
        local current_version=$(node --version)
        log_info "Node already installed: $current_version"
    else
        log_info "Installing Node $NODE_VERSION via NVM..."

        if ! nvm install "$NODE_VERSION"; then
            log_error "Failed to install Node $NODE_VERSION"
            return 1
        fi

        nvm use "$NODE_VERSION"
        nvm alias default "$NODE_VERSION"
    fi

    # Add NVM to .bashrc if not already there
    if ! grep -q "NVM_DIR" ~/.bashrc; then
        log_info "Adding NVM configuration to ~/.bashrc"
        echo "" >> ~/.bashrc
        echo 'export NVM_DIR="$HOME/.nvm"' >> ~/.bashrc
        echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> ~/.bashrc
    fi
}

install_uv() {
    if check_cmd uv; then
        local version=$(uv --version)
        log_info "uv already installed: $version"
    else
        log_info "Installing uv..."

        local uv_url="https://astral.sh/uv/install.sh"
        local temp_file=$(mktemp)

        if safe_download "$uv_url" "$temp_file"; then
            safe_execute "$temp_file" "uv installer"
            rm -f "$temp_file"
        else
            log_error "Failed to install uv"
            return 1
        fi
    fi
}

install_docker() {
    if check_cmd docker; then
        local version=$(docker --version)
        log_info "Docker already installed: $version"

        # Check if user is in docker group
        if groups | grep -q docker; then
            log_info "User already in docker group"
        else
            log_info "Adding user to docker group..."
            sudo usermod -aG docker $USER
            log_warn "You need to log out and log back in for docker group changes to take effect"
            log_warn "Or run: newgrp docker"
        fi
    else
        log_info "Installing Docker..."

        local docker_url="https://get.docker.com"
        local temp_file=$(mktemp)

        if safe_download "$docker_url" "$temp_file"; then
            safe_execute "$temp_file" "Docker installer"
            rm -f "$temp_file"
        else
            log_error "Failed to install Docker"
            return 1
        fi

        log_info "Adding user to docker group..."
        sudo usermod -aG docker $USER
    fi
}

################################
# Execute installation
################################

FAILED_INSTALLATIONS=""

for c in $CHOICES
do
    c=$(echo $c | tr -d '"')

    echo ""
    log_info "========== Installing $c =========="

    case $c in
        git)
            if ! install_git; then
                FAILED_INSTALLATIONS+="$c "
            fi
            ;;
        java)
            if ! install_java; then
                FAILED_INSTALLATIONS+="$c "
            fi
            ;;
        maven)
            if ! install_maven; then
                FAILED_INSTALLATIONS+="$c "
            fi
            ;;
        node)
            if ! install_node; then
                FAILED_INSTALLATIONS+="$c "
            fi
            ;;
        uv)
            if ! install_uv; then
                FAILED_INSTALLATIONS+="$c "
            fi
            ;;
        docker)
            if ! install_docker; then
                FAILED_INSTALLATIONS+="$c "
            fi
            ;;
        *)
            log_warn "Unknown component: $c"
            ;;
    esac

    echo "========== Done with $c =========="
done

################################
# Final summary
################################

echo ""
echo "=================================="
echo "Installation Summary"
echo "=================================="
echo ""

for c in $CHOICES
do
    c=$(echo $c | tr -d '"')
    if [[ ! " $FAILED_INSTALLATIONS " =~ " $c " ]]; then
        echo -e "${GREEN}✓${NC} $c installed successfully"
    else
        echo -e "${RED}✗${NC} $c installation failed"
    fi
done

echo ""

# Show post-installation notes
if [[ $CHOICES == *"docker"* ]]; then
    log_warn "Docker: You may need to log out and log back in to use docker without sudo"
    echo "  Or run: newgrp docker"
    echo ""
fi

if [[ $CHOICES == *"node"* ]]; then
    log_warn "Node.js: If nvm commands are not available, run: source ~/.bashrc"
    echo ""
fi

if [ -n "$FAILED_INSTALLATIONS" ]; then
    log_error "Some components failed to install: $FAILED_INSTALLATIONS"
    log_error "Please check the errors above and try installing them manually"
    exit 1
else
    log_info "All components installed successfully!"
    echo ""
    echo "To apply all changes, please run:"
    echo "  source ~/.bashrc"
    echo ""
fi
