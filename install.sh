#!/bin/bash

# -----------------------------------------
# 🔧 rec0n+ Dependency Installer
# Author: Duaij Almutairi (@0xMutairi)
# -----------------------------------------

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

TOOLS=(
  subfinder
  assetfinder
  dnsx
  httpx
  gau
  waybackurls
  qsreplace
  gowitness
)

LOGFILE="rec0n-install.log"

echo -e "${YELLOW}[+] Installing Go if not found...${NC}"
if ! command -v go &>/dev/null; then
  sudo apt update && sudo apt install -y golang
fi

export GO111MODULE=on
export PATH=$PATH:$(go env GOPATH)/bin

echo -e "${CYAN}[*] Installing rec0n+ dependencies...${NC}"
for tool in "${TOOLS[@]}"; do
  echo -e "${YELLOW}Installing $tool...${NC}"
  go install github.com/projectdiscovery/$tool/cmd/$tool@latest 2>> "$LOGFILE"
done

# Install ffuf if desired for future fuzzing
if ! command -v ffuf &>/dev/null; then
  echo -e "${YELLOW}Installing ffuf...${NC}"
  go install github.com/ffuf/ffuf/v2@latest 2>> "$LOGFILE"
fi

# Optional: install dig if not installed
if ! command -v dig &>/dev/null; then
  echo -e "${YELLOW}Installing dnsutils for dig...${NC}"
  sudo apt install -y dnsutils 2>> "$LOGFILE"
fi

# Check curl
if ! command -v curl &>/dev/null; then
  echo -e "${YELLOW}Installing curl...${NC}"
  sudo apt install -y curl 2>> "$LOGFILE"
fi

# Check if gowitness requires setup
if ! command -v gowitness &>/dev/null; then
  echo -e "${RED}[!] gowitness may require Chrome/Chromium to function properly.${NC}"
fi

# Make rec0n+ global alias
SCRIPT_DIR=$(cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P)
RECON_SCRIPT="$SCRIPT_DIR/rec0n.sh"

if [[ -f "$RECON_SCRIPT" ]]; then
  echo -e "\n${CYAN}[*] Installing rec0n+ as a system-wide command...${NC}"
  sudo cp "$RECON_SCRIPT" /usr/local/bin/rec0n
  sudo chmod +x /usr/local/bin/rec0n
else
  echo -e "${RED}[!] rec0n.sh not found in $SCRIPT_DIR. Skipping installation to /usr/local/bin.${NC}"
fi

# Finished
echo -e "\n${GREEN}[✓] All tools installed. You can now run 'rec0n' from anywhere!${NC}"
echo -e "Run: rec0n target.com --fast or --deep"
echo -e "\n${YELLOW}[*] If any tool failed to install, check the log at: $LOGFILE${NC}"
