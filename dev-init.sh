#!/usr/bin/env bash

set -e

################################
# install dependency
################################

if ! command -v whiptail >/dev/null; then
    sudo apt update
    sudo apt install -y whiptail
fi

################################
# choose components
################################

CHOICES=$(whiptail --title "Dev Environment Setup" \
--checklist "Select components to install" 20 60 10 \
"git" "Git" ON \
"java" "OpenJDK" ON \
"maven" "Maven" OFF \
"node" "Node.js (via NVM)" ON \
"uv" "Python uv" OFF \
"docker" "Docker" OFF \
3>&1 1>&2 2>&3)

clear

################################
# version selection
################################

JAVA_VERSION=17
NODE_VERSION=lts

if [[ $CHOICES == *"java"* ]]; then

JAVA_VERSION=$(whiptail --title "Java Version" \
--menu "Select JDK version" 15 60 4 \
17 "LTS" \
21 "LTS" \
3>&1 1>&2 2>&3)

fi

if [[ $CHOICES == *"node"* ]]; then

NODE_VERSION=$(whiptail --title "Node Version" \
--menu "Select Node version" 15 60 4 \
lts "Latest LTS" \
20 "Node 20" \
18 "Node 18" \
3>&1 1>&2 2>&3)

fi

################################
# summary
################################

SUMMARY="You selected:\n\n"

for c in $CHOICES
do
    c=$(echo $c | tr -d '"')
    SUMMARY+="✔ $c\n"
done

SUMMARY+="\nContinue installation?"

whiptail --title "Confirm Installation" \
--yesno "$SUMMARY" 20 60

clear

################################
# helper
################################

check_cmd() {
    command -v "$1" >/dev/null
}

install_pkg() {
    sudo apt install -y "$@"
}

################################
# install functions
################################

install_git() {

if check_cmd git; then
    echo "Git already installed"
else
    install_pkg git
fi

}

install_java() {

if check_cmd java; then
    echo "Java already installed"
else
    install_pkg openjdk-${JAVA_VERSION}-jdk
fi

}

install_maven() {

if check_cmd mvn; then
    echo "Maven already installed"
else
    install_pkg maven
fi

}

install_node() {

export NVM_DIR="$HOME/.nvm"

if [ ! -d "$NVM_DIR" ]; then
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
fi

source "$NVM_DIR/nvm.sh"

if check_cmd node; then
    echo "Node already installed"
else
    nvm install $NODE_VERSION
fi

}

install_uv() {

if check_cmd uv; then
    echo "uv already installed"
else
    curl -LsSf https://astral.sh/uv/install.sh | sh
fi

}

install_docker() {

if check_cmd docker; then
    echo "Docker already installed"
else
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker $USER
fi

}

################################
# execute
################################

for c in $CHOICES
do

c=$(echo $c | tr -d '"')

echo "========== installing $c =========="

case $c in
git) install_git ;;
java) install_java ;;
maven) install_maven ;;
node) install_node ;;
uv) install_uv ;;
docker) install_docker ;;
esac

done

################################
# done
################################

echo ""
echo "Installation finished!"
