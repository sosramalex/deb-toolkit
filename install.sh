#!/usr/bin/env bash
set -u

log()  { echo "[+] $1"; }
info() { echo "[*] $1"; }
err()  { echo "[-] $1" >&2; }

MANIFEST_URL="https://raw.githubusercontent.com/alsosram/deb-toolkit/master/tools.json"

usage() {
    cat <<EOF
Usage: bash install.sh [options]

Options:
  --list          List available tools and exit
  <number>        Run a specific tool by number (non-interactive)
  --help          Show this help
EOF
    exit 0
}

[[ $# -ge 1 && "$1" == "--help" ]] && usage

# Fetch toolbox manifest
TOOLS=()
while IFS='|' read -r name desc url; do
    TOOLS+=("$name|$desc|$url")
done < <(curl -fsSL "$MANIFEST_URL" 2>/dev/null | python3 -c "
import sys, json
for t in json.load(sys.stdin):
    print(t['name'] + '|' + t['desc'] + '|' + t['url'])
" 2>/dev/null)

if [[ ${#TOOLS[@]} -eq 0 ]]; then
    err "Failed to fetch toolbox manifest."
    err "Try again or manually run a tool:"
    echo "  curl -fsSL https://raw.githubusercontent.com/alsosram/deb-autoset/main/install.sh | bash"
    exit 1
fi

[[ $# -ge 1 && "$1" == "--list" ]] && {
    info "Available tools:"
    for i in "${!TOOLS[@]}"; do
        IFS='|' read -r name desc _ <<< "${TOOLS[$i]}"
        [[ "${#desc}" -gt 50 ]] && desc="${desc:0:47}..."
        echo "  $((i+1))) $name — $desc"
    done
    exit 0
}

run_tool() {
    local idx=$1
    IFS='|' read -r name desc url <<< "${TOOLS[$idx]}"
    local full_url="https://raw.githubusercontent.com/alsosram/$url"

    if whiptail --yesno --title "$name" \
        "Tool:  ${name}\n\
Description:  ${desc}\n\n\
This tool will be downloaded from GitHub and executed.\n\
Source: ${full_url}\n\n\
Download and run now?" 12 65; then
        bash <(curl -fsSL "$full_url") < /dev/tty
    fi
}

# --- Main ---
if [[ $# -ge 1 ]]; then
    if [[ "$1" =~ ^[0-9]+$ ]]; then
        idx=$(( $1 - 1 ))
        if [[ $idx -ge 0 && $idx -lt ${#TOOLS[@]} ]]; then
            run_tool $idx
            exit 0
        fi
    fi
    err "Invalid option: $1"
    usage
fi

if ! command -v whiptail &>/dev/null; then
    echo "[!] whiptail is required. Install: apt-get install whiptail" >&2
    exit 1
fi

while true; do
    menu_args=()
    menu_args+=("--title" "Debian Tool Kit" "--menu" "Select a tool to run:" "18" "70" "8")
    for i in "${!TOOLS[@]}"; do
        IFS='|' read -r name desc _ <<< "${TOOLS[$i]}"
        [[ "${#desc}" -gt 35 ]] && desc="${desc:0:32}..."
        menu_args+=("$((i+1))" "${name} — ${desc}")
    done
    menu_args+=("Q" "Quit")

    choice=$(whiptail "${menu_args[@]}" 3>&1 1>&2 2>&3) || {
        log "Goodbye."
        exit 0
    }
    if [[ "$choice" == "Q" ]]; then
        log "Goodbye."
        exit 0
    fi
    idx=$(( choice - 1 ))
    run_tool $idx
    if [[ -t 0 ]]; then
        read -rp "  Press Enter to continue..."
    fi
done
