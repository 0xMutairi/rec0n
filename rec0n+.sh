#!/bin/bash

# -------------------------------------
# 🛡️ rec0n+ - Fast & Deep Recon Toolkit 🛡️
# 👨‍💻 Author: Duaij Almutairi (@0xmutairi)
# -------------------------------------

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

domain=$1
mode=$2
start=$(date)
today=$(date +%Y-%m-%d)

# Help Menu
show_help() {
  echo -e "
${CYAN}rec0n+ - Fast & Deep Recon Toolkit by 0xMutairi${NC}

${YELLOW}Usage:${NC}
  rec0n <domain> [--fast | --deep]

${YELLOW}Modes:${NC}
  --fast        Basic recon: subdomains, DNS, web detection
  --deep        Full recon: archive, JS, secrets, screenshots, etc.
  (no flag)     Interactive mode (manual selection)

${YELLOW}Examples:${NC}
  rec0n example.com --fast
  rec0n target.org --deep
  rec0n vuln.gov
"
  exit 0
}

# Handle help flag
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
  show_help
fi

# Validate domain format
if [[ -z "$domain" || ! "$domain" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
  echo -e "${RED}[!] Please provide a valid domain (e.g., example.com)${NC}"
  echo "Try: rec0n example.com --fast"
  exit 1
fi

# Setup folders
mkdir -p recon/${domain}_${today}/{subdomains,ips,webs,params,wayback,screenshots,novel}
cd recon/${domain}_${today}

# Display Banner
echo -e "${CYAN}"
echo "██████╗░███████╗░█████╗░░█████╗░███╗░░██╗"
echo "██╔══██╗██╔════╝██╔══██╗██╔══██╗████╗░██║"
echo "██████╔╝█████╗░░██║░░╚═╝██║░░██║██╔██╗██║"
echo "██╔══██╗██╔══╝░░██║░░██╗██║░░██║██║╚████║"
echo "██║░░██║███████╗╚█████╔╝╚█████╔╝██║░╚███║"
echo "╚═╝░░╚═╝╚══════╝░╚════╝░░╚════╝░╚═╝░░╚══╝  by 0xMutairi"
echo -e "${YELLOW}➤ Target: ${domain}"
echo "➤ Started at: ${start}${NC}"
echo

# FAST MODE
if [[ "$mode" == "--fast" ]]; then
  echo -e "${CYAN}[+] Running FAST recon...${NC}"
  subfinder -d $domain -silent > subdomains/subfinder.txt
  assetfinder --subs-only $domain > subdomains/assetfinder.txt
  cat subdomains/*.txt | sort -u > subdomains/final.txt
  dnsx -silent -l subdomains/final.txt -resp-only > ips/resolved.txt
  httpx -silent -l subdomains/final.txt -status-code -title -tech-detect -threads 100 | tee webs/alive.txt
  cut -d' ' -f1 webs/alive.txt > webs/live_hosts.txt

# DEEP MODE
elif [[ "$mode" == "--deep" ]]; then
  echo -e "${CYAN}[+] Running DEEP recon...${NC}"

  run_subdomain_enum() {
    subfinder -d $domain -silent > subdomains/subfinder.txt
    assetfinder --subs-only $domain > subdomains/assetfinder.txt
    cat subdomains/*.txt | sort -u > subdomains/final.txt
  }

  run_dns_resolution() {
    dnsx -silent -l subdomains/final.txt -resp-only > ips/resolved.txt
  }

  run_web_discovery() {
    httpx -silent -l subdomains/final.txt -status-code -title -tech-detect -threads 100 | tee webs/alive.txt
    cut -d' ' -f1 webs/alive.txt > webs/live_hosts.txt
  }

  run_archive_collection() {
    waybackurls < webs/live_hosts.txt > wayback/wayback.txt
    gau --threads 50 < webs/live_hosts.txt > wayback/gau.txt
    cat wayback/*.txt | sort -u > wayback/all_urls.txt
  }

  run_param_extraction() {
    grep '=' wayback/all_urls.txt | qsreplace FUZZ > params/params.txt
  }

  run_js_secret_scan() {
    grep -Ei '\.js($|\?)' wayback/all_urls.txt > params/jsfiles.txt
    for js in $(cat params/jsfiles.txt); do
      curl -s "$js" | grep -Eo '(apikey|secret|token|pass|key)["'=: ]+[^"'\n]+' >> novel/js_secrets.txt
    done
  }

  run_screenshots() {
    gowitness file -f webs/live_hosts.txt --timeout 7s --threads 10 --log-level fatal > /dev/null 2>&1
  }

  run_cdn_waf_detection() {
    for url in $(cat webs/live_hosts.txt); do
      ip=$(dig +short ${url##*//} | tail -n1)
      echo "$url -> $ip" >> novel/cdn_ip.txt
    done
  }

  run_auth_redirect_discovery() {
    for url in $(cat webs/live_hosts.txt); do
      curl -Ls -o /dev/null -w "%{url_effective}\n" "$url" >> novel/redirects.txt
      curl -s "$url" | grep -Eo 'sso|saml|oauth|login' | sort -u >> novel/auth_keywords.txt
    done
    sort -u novel/auth_keywords.txt > novel/auth_detected.txt
  }

  run_robots_sitemap() {
    for url in $(cat webs/live_hosts.txt); do
      curl -s "$url/robots.txt" >> novel/robots.txt
      curl -s "$url/sitemap.xml" >> novel/sitemap.xml
    done
  }

  run_subdomain_enum
  run_dns_resolution
  run_web_discovery
  run_archive_collection
  run_param_extraction
  run_js_secret_scan
  run_screenshots
  run_cdn_waf_detection
  run_auth_redirect_discovery
  run_robots_sitemap

# CUSTOM (Interactive)
else
  show_menu() {
    echo -e "${YELLOW}[?] Choose modules to run (e.g. 1 3 6):${NC}"
    echo "[1] Subdomain Enum"
    echo "[2] DNS Resolve"
    echo "[3] Web Discovery"
    echo "[4] Archive URL Collection"
    echo "[5] Param Extraction"
    echo "[6] JS Secrets Scan"
    echo "[7] Screenshot"
    echo "[8] CDN/WAF Detection"
    echo "[9] Auth/Redirect Check"
    echo "[10] robots.txt/sitemap"
  }

  run_choice_modules() {
    for i in $1; do
      case $i in
        1) run_subdomain_enum;;
        2) run_dns_resolution;;
        3) run_web_discovery;;
        4) run_archive_collection;;
        5) run_param_extraction;;
        6) run_js_secret_scan;;
        7) run_screenshots;;
        8) run_cdn_waf_detection;;
        9) run_auth_redirect_discovery;;
        10) run_robots_sitemap;;
        *) echo -e "${RED}[!] Invalid option: $i${NC}";;
      esac
    done
  }

  show_menu
  read -p "Select: " input
  echo
  run_choice_modules "$input"
fi

end=$(date)
echo -e "\n${GREEN}[✓] Recon complete for: ${domain}${NC}"
echo -e "${YELLOW}Started at: ${start}"
echo -e "Finished at: ${end}${NC}"
echo -e "${CYAN}Results saved in: recon/${domain}_${today}/${NC}"
