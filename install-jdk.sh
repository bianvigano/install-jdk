#!/usr/bin/env bash
# install-jdk.sh — Interactive multi-JDK installer for Debian/Ubuntu
# Usage: curl -fsSL https://raw.githubusercontent.com/bianvigano/install-jdk/main/install-jdk.sh | bash
#
# Checkbox-style selection menu. Pick which JDKs to install.
# Supports: JDK 8, 11, 17, 21, 24 via apt (Temurin/OpenJDK)

set -Eeuo pipefail

# Check if stdin is a terminal (interactive) or pipe (curl | bash)
INTERACTIVE=false
[[ -t 0 ]] && INTERACTIVE=true

AUTO_ALL=false
UNINSTALL=false
if [[ "${1:-}" == "--all" ]]; then
  AUTO_ALL=true
elif [[ "${1:-}" == "--uninstall" ]]; then
  UNINSTALL=true
fi

RED='\033[0;31m'; GRN='\033[0;32m'; YLW='\033[1;33m'
CYA='\033[0;36m'; MAG='\033[0;35m'; WHT='\033[1;37m'; NC='\033[0m'
BLD='\033[1m'; DIM='\033[2m'; REV='\033[7m'

ok()   { echo -e "${GRN}[✓]${NC} $*"; }
err()  { echo -e "${RED}[✗]${NC} $*"; }
info() { echo -e "${CYA}[•]${NC} $*"; }
warn() { echo -e "${YLW}[!]${NC} $*"; }

# Check root
if [[ $EUID -ne 0 ]] && ! command -v sudo &>/dev/null; then
  err "Need root. Run: sudo bash install-jdk.sh"
  exit 1
fi
SUDO=""
[[ $EUID -ne 0 ]] && SUDO="sudo"

# ── OS Check ─────────────────────────────────────────────
if grep -qi "ubuntu" /etc/os-release 2>/dev/null; then OS="ubuntu"
elif grep -qi "debian" /etc/os-release 2>/dev/null; then OS="debian"
else
  err "Unsupported OS. Only Debian/Ubuntu supported."
  exit 1
fi

# ── JDK definitions ──────────────────────────────────────
JDK_NAMES=("JDK 8" "JDK 11" "JDK 17" "JDK 21" "JDK 24")
JDK_KEYS=(8 11 17 21 24)
JDK_DESC=(
  "Legacy Minecraft (Forge 1.12, Spigot 1.8)"
  "Minecraft 1.16.x, older Fabric"
  "Minecraft 1.18-1.20, modern Forge"
  "Minecraft 1.21+, Paper, latest plugins"
  "Latest features, preview builds"
)

# ── State ────────────────────────────────────────────────
SELECTED=()
INSTALLED=()
AVAILABLE=()

for v in "${JDK_KEYS[@]}"; do SELECTED+=("false"); done

# Check already installed
for i in "${!JDK_KEYS[@]}"; do
  v="${JDK_KEYS[$i]}"
  if find /usr/lib/jvm -maxdepth 1 -name "java-${v}-*" -o -name "temurin-${v}-*" 2>/dev/null | grep -q .; then
    INSTALLED+=("true")
    SELECTED[$i]="done"
  elif command -v javac &>/dev/null && javac --version 2>&1 | grep -q "javac $v\b"; then
    INSTALLED+=("true")
    SELECTED[$i]="done"
  else
    INSTALLED+=("false")
    AVAILABLE+=("$v")
  fi
done

# ── Cursor drawing ───────────────────────────────────────
POS=0
while [[ "${SELECTED[$POS]}" == "done" ]]; do POS=$((POS + 1)); done

# Catch first available
if [[ $POS -ge ${#JDK_KEYS[@]} ]]; then
  echo ""
  ok "All JDK versions already installed."
  exit 0
fi

draw_menu() {
  clear 2>/dev/null || true
  echo ""
  echo -e "  ${WHT}${BLD}╔══════════════════════════════════════════════╗${NC}"
  echo -e "  ${WHT}${BLD}║${NC}     ${MAG}${BLD}🔧 INSTALL JDK — Pilih Versi${NC}"
  echo -e "  ${WHT}${BLD}╚══════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "  ${DIM}OS: $OS   |   [Space] centang   |   [Enter] install   |   [r] hapus   |   [d] uninstall   |   [q] batal${NC}"
  echo ""

  for i in "${!JDK_KEYS[@]}"; do
    local name="${JDK_NAMES[$i]}"
    local desc="${JDK_DESC[$i]}"
    local state="${SELECTED[$i]}"
    local prefix="  "
    local mark="[ ]"
    local color="$DIM"

    if [[ $i -eq $POS ]]; then
      prefix="  ${REV}"
      color=""
    fi

    if [[ "$state" == "done" ]]; then
      mark="[✓]"
      color="${GRN}"
    elif [[ "$state" == "true" ]]; then
      mark="[${CYA}✔${NC}${color}]"
    fi

    echo -e "${prefix}${color}  ${mark} ${BLD}${name}${NC}${color}  ${DIM}— ${desc}${NC}\033[0m"
  done

  echo ""
  echo -e "  ${DIM}Terpilih: ${CYA}$(count_selected)${NC}"

  # Show summary of selected
  for i in "${!JDK_KEYS[@]}"; do
    if [[ "${SELECTED[$i]}" == "true" ]]; then
      echo -e "    ${GRN}→${NC} ${JDK_NAMES[$i]}"
    fi
  done
  echo ""
  echo -e "  ${DIM}[Enter] Install   [Space] Pilih   [a] Semua   [r] Hapus per baris   [d] Uninstall   [q] Batal${NC}"
  echo ""
}

count_selected() {
  local c=0
  for s in "${SELECTED[@]}"; do [[ "$s" == "true" ]] && c=$((c + 1)); done
  echo "$c"
}

# ── Install selected ─────────────────────────────────────
install_selected() {
  local count; count=$(count_selected)
  if [[ $count -eq 0 ]]; then
    echo ""
    warn "Tidak ada JDK dipilih. Pilih minimal satu."
    sleep 1
    return
  fi

  clear 2>/dev/null || true
  echo ""
  echo -e "  ${WHT}${BLD}╔══════════════════════════════════════════════╗${NC}"
  echo -e "  ${WHT}${BLD}║${NC}     ${CYA}${BLD}⏳ INSTALLING JDK...${NC}"
  echo -e "  ${WHT}${BLD}╚══════════════════════════════════════════════╝${NC}"
  echo ""

  $SUDO apt-get update -qq 2>/dev/null || true

  local default_v=21
  local installed_any=false

  for i in "${!JDK_KEYS[@]}"; do
    [[ "${SELECTED[$i]}" != "true" ]] && continue
    local v="${JDK_KEYS[$i]}"
    echo ""
    info "Installing JDK $v..."

    local pkg=""
    if apt-cache show "temurin-${v}-jdk" &>/dev/null 2>&1; then
      pkg="temurin-${v}-jdk"
    elif apt-cache show "openjdk-${v}-jdk" &>/dev/null 2>&1; then
      pkg="openjdk-${v}-jdk"
    elif apt-cache show "openjdk-${v}-jdk-headless" &>/dev/null 2>&1; then
      pkg="openjdk-${v}-jdk-headless"
    else
      err "JDK $v: no package found. Skipped."
      continue
    fi

    if $SUDO apt-get install -y -qq "$pkg" 2>/dev/null; then
      ok "JDK $v ($pkg)"
      installed_any=true
    else
      err "JDK $v failed to install."
    fi
  done

  if ! $installed_any; then
    err "No JDK installed."
    exit 1
  fi

  echo ""

  # Set default
  info "Setting JDK 21 as default..."
  for cmd in java javac jar; do
    for jvm_dir in /usr/lib/jvm/java-21-openjdk-amd64 /usr/lib/jvm/temurin-21-jdk-amd64; do
      if [[ -f "$jvm_dir/bin/$cmd" ]]; then
        $SUDO update-alternatives --set "$cmd" "$jvm_dir/bin/$cmd" 2>/dev/null || true
        break
      fi
    done
  done

  # JAVA_HOME
  JAVA_HOME_PATH=""
  for d in /usr/lib/jvm/java-21-openjdk-amd64 /usr/lib/jvm/temurin-21-jdk-amd64; do
    if [[ -d "$d" ]]; then JAVA_HOME_PATH="$d"; break; fi
  done

  if [[ -n "$JAVA_HOME_PATH" ]]; then
    if ! grep -q "JAVA_HOME" /etc/environment 2>/dev/null; then
      echo "JAVA_HOME=$JAVA_HOME_PATH" | $SUDO tee -a /etc/environment >/dev/null
    fi
    $SUDO tee /etc/profile.d/jdk.sh >/dev/null <<EOF
export JAVA_HOME=$JAVA_HOME_PATH
export PATH=\$JAVA_HOME/bin:\$PATH
EOF
    $SUDO chmod 644 /etc/profile.d/jdk.sh
    ok "JAVA_HOME=$JAVA_HOME_PATH"
  fi

  echo ""
  ok "Semua JDK terinstall!"
  echo ""
  java --version 2>&1 || true
  echo ""
  echo "  Run: source /etc/profile.d/jdk.sh"
  echo ""

  exit 0
}

# ── Non-interactive auto-install ─────────────────────────
auto_install_all() {
  clear 2>/dev/null || true
  echo ""
  echo "════════════════════════════════════════════"
  echo "  JDK Auto-Installer (non-interactive)"
  echo "════════════════════════════════════════════"
  echo ""
  echo " Installing: JDK 8, 11, 17, 21, 24"
  echo ""

  # Mark all not-done as selected
  for i in "${!JDK_KEYS[@]}"; do
    [[ "${SELECTED[$i]}" != "done" ]] && SELECTED[$i]="true"
  done

  local count; count=$(count_selected)
  if [[ $count -eq 0 ]]; then
    ok "All JDK versions already installed."
    java --version 2>&1 || true
    exit 0
  fi

  $SUDO apt-get update -qq 2>/dev/null || true

  for i in "${!JDK_KEYS[@]}"; do
    [[ "${SELECTED[$i]}" != "true" ]] && continue
    local v="${JDK_KEYS[$i]}"
    echo ""
    info "Installing JDK $v..."

    local pkg=""
    if apt-cache show "temurin-${v}-jdk" &>/dev/null 2>&1; then
      pkg="temurin-${v}-jdk"
    elif apt-cache show "openjdk-${v}-jdk" &>/dev/null 2>&1; then
      pkg="openjdk-${v}-jdk"
    elif apt-cache show "openjdk-${v}-jdk-headless" &>/dev/null 2>&1; then
      pkg="openjdk-${v}-jdk-headless"
    else
      err "JDK $v: no package found. Skipped."
      continue
    fi

    if $SUDO apt-get install -y -qq "$pkg" 2>/dev/null; then
      ok "JDK $v ($pkg)"
    else
      err "JDK $v failed to install."
    fi
  done

  # Default + JAVA_HOME
  echo ""
  info "Setting JDK 21 as default..."
  for cmd in java javac jar; do
    for jvm_dir in /usr/lib/jvm/java-21-openjdk-amd64 /usr/lib/jvm/temurin-21-jdk-amd64; do
      if [[ -f "$jvm_dir/bin/$cmd" ]]; then
        $SUDO update-alternatives --set "$cmd" "$jvm_dir/bin/$cmd" 2>/dev/null || true
        break
      fi
    done
  done

  local jh=""
  for d in /usr/lib/jvm/java-21-openjdk-amd64 /usr/lib/jvm/temurin-21-jdk-amd64; do
    if [[ -d "$d" ]]; then jh="$d"; break; fi
  done

  if [[ -n "$jh" ]]; then
    if ! grep -q "JAVA_HOME" /etc/environment 2>/dev/null; then
      echo "JAVA_HOME=$jh" | $SUDO tee -a /etc/environment >/dev/null
    fi
    $SUDO tee /etc/profile.d/jdk.sh >/dev/null <<EOF
export JAVA_HOME=$jh
export PATH=\$JAVA_HOME/bin:\$PATH
EOF
    $SUDO chmod 644 /etc/profile.d/jdk.sh
    ok "JAVA_HOME=$jh"
  fi

  echo ""
  ok "Done!"
  java --version 2>&1 || true
  echo ""
  echo "  Run: source /etc/profile.d/jdk.sh"
  echo ""
  exit 0
}

# ── Main Loop ────────────────────────────────────────────
# Auto mode if piped (curl | bash) or --all flag
if ! $INTERACTIVE || $AUTO_ALL; then
  auto_install_all
fi

while true; do
  draw_menu

  # Read single keypress
  IFS= read -rsn1 key

  case "$key" in
    $'\x1b')  # Escape sequence (arrow keys)
      read -rsn2 -t 0.001 rest || true
      case "$rest" in
        '[A')  # Up
          POS=$((POS - 1))
          while [[ $POS -ge 0 ]] && [[ "${SELECTED[$POS]}" == "done" ]]; do POS=$((POS - 1)); done
          [[ $POS -lt 0 ]] && POS=0
          ;;
        '[B')  # Down
          POS=$((POS + 1))
          while [[ $POS -lt ${#JDK_KEYS[@]} ]] && [[ "${SELECTED[$POS]}" == "done" ]]; do POS=$((POS + 1)); done
          [[ $POS -ge ${#JDK_KEYS[@]} ]] && POS=$((${#JDK_KEYS[@]} - 1))
          ;;
      esac
      ;;
    ' ')  # Toggle checkbox
      if [[ "${SELECTED[$POS]}" == "false" ]]; then
        SELECTED[$POS]="true"
      elif [[ "${SELECTED[$POS]}" == "true" ]]; then
        SELECTED[$POS]="false"
      fi
      ;;
    'a'|'A')  # Select all
      for i in "${!JDK_KEYS[@]}"; do
        [[ "${SELECTED[$i]}" != "done" ]] && SELECTED[$i]="true"
      done
      ;;
    'n'|'N')  # Deselect all
      for i in "${!JDK_KEYS[@]}"; do
        [[ "${SELECTED[$i]}" != "done" ]] && SELECTED[$i]="false"
      done
      ;;
    'q'|'Q')
      echo ""
      warn "Dibatalkan."
      exit 0
      ;;
    'd'|'D')
      uninstall_from_menu
      ;;
    'r'|'R')
      remove_single_jdk
      ;;
    '')  # Enter
      install_selected
      ;;
  esac
done

# ── Uninstall Mode ──────────────────────────────────────
uninstall_jdks() {
  clear 2>/dev/null || true
  echo ""
  echo -e "  ${WHT}${BLD}╔══════════════════════════════════════════════╗${NC}"
  echo -e "  ${WHT}${BLD}║${NC}     ${RED}${BLD}🗑  UNINSTALL JDK — Hapus Versi${NC}"
  echo -e "  ${WHT}${BLD}╚══════════════════════════════════════════════╝${NC}"
  echo ""

  # Find installed JDK packages
  local pkg_list=()
  for v in "${JDK_KEYS[@]}"; do
    for prefix in "temurin-${v}-jdk" "openjdk-${v}-jdk" "openjdk-${v}-jdk-headless"; do
      if dpkg -l "$prefix" &>/dev/null 2>&1; then
        pkg_list+=("$prefix")
        break
      fi
    done
  done

  if [[ ${#pkg_list[@]} -eq 0 ]]; then
    ok "No JDK packages found via apt."
    exit 0
  fi

  echo "  ${DIM}Packages to remove:${NC}"
  for p in "${pkg_list[@]}"; do
    echo -e "    ${RED}✗${NC} $p"
  done
  echo ""

  echo -ne "  ${YLW}Remove these packages? [y/N]${NC} "
  read -r confirm
  if [[ "$confirm" != "y" ]] && [[ "$confirm" != "Y" ]]; then
    warn "Dibatalkan."
    exit 0
  fi

  echo ""
  for p in "${pkg_list[@]}"; do
    info "Removing $p..."
    $SUDO apt-get remove -y -qq "$p" 2>/dev/null && ok "Removed $p" || err "Failed: $p"
  done

  $SUDO apt-get autoremove -y -qq 2>/dev/null || true

  # Clean leftovers
  for v in "${JDK_KEYS[@]}"; do
    for jvm_dir in /usr/lib/jvm/java-${v}-openjdk-amd64 /usr/lib/jvm/temurin-${v}-jdk-amd64; do
      if [[ -d "$jvm_dir" ]]; then
        info "Removing leftover: $jvm_dir"
        $SUDO rm -rf "$jvm_dir" 2>/dev/null && ok "Cleaned $jvm_dir"
      fi
    done
  done

  # Clean JAVA_HOME if empty
  if [[ ! "$(find /usr/lib/jvm -maxdepth 1 -type d -name 'java-*' -o -name 'temurin-*' 2>/dev/null)" ]]; then
    $SUDO rm -f /etc/profile.d/jdk.sh
    ok "Removed /etc/profile.d/jdk.sh"
  fi

  echo ""
  ok "Uninstall selesai."
  exit 0
}

# ── Uninstall from menu (interactive) ────────────────────
uninstall_from_menu() {
  clear 2>/dev/null || true
  echo ""
  echo -e "  ${WHT}${BLD}╔══════════════════════════════════════════════╗${NC}"
  echo -e "  ${WHT}${BLD}║${NC}     ${RED}${BLD}🗑  UNINSTALL JDK${NC}"
  echo -e "  ${WHT}${BLD}╚══════════════════════════════════════════════╝${NC}"
  echo ""

  # Find installed JDK packages
  local pkg_list=()
  for v in "${JDK_KEYS[@]}"; do
    for prefix in "temurin-${v}-jdk" "openjdk-${v}-jdk" "openjdk-${v}-jdk-headless"; do
      if dpkg -l "$prefix" &>/dev/null 2>&1; then
        pkg_list+=("$prefix")
        break
      fi
    done
  done

  if [[ ${#pkg_list[@]} -eq 0 ]]; then
    ok "No JDK packages found."
    echo ""
    echo -ne "  ${DIM}Press Enter...${NC}"; read -r
    return
  fi

  echo -e "  ${DIM}Found packages:${NC}"
  for p in "${pkg_list[@]}"; do
    echo -e "    ${RED}✗${NC} $p"
  done
  echo ""

  echo -ne "  ${YLW}Remove ALL installed JDKs? [y/N]${NC} "
  read -r confirm
  if [[ "$confirm" != "y" ]] && [[ "$confirm" != "Y" ]]; then
    warn "Dibatalkan."
    echo ""
    echo -ne "  ${DIM}Press Enter...${NC}"; read -r
    return
  fi

  echo ""
  for p in "${pkg_list[@]}"; do
    info "Removing $p..."
    $SUDO apt-get remove -y -qq "$p" 2>/dev/null && ok "Removed $p" || err "Failed: $p"
  done

  $SUDO apt-get autoremove -y -qq 2>/dev/null || true

  # Clean leftovers
  for v in "${JDK_KEYS[@]}"; do
    for jvm_dir in /usr/lib/jvm/java-${v}-openjdk-amd64 /usr/lib/jvm/temurin-${v}-jdk-amd64; do
      if [[ -d "$jvm_dir" ]]; then
        info "Removing leftover: $jvm_dir"
        $SUDO rm -rf "$jvm_dir" 2>/dev/null && ok "Cleaned $jvm_dir"
      fi
    done
  done

  if ! find /usr/lib/jvm -maxdepth 1 -type d \( -name 'java-*' -o -name 'temurin-*' \) 2>/dev/null | grep -q .; then
    $SUDO rm -f /etc/profile.d/jdk.sh
    ok "Removed /etc/profile.d/jdk.sh"
  fi

  echo ""
  ok "Uninstall selesai."
  echo ""
  echo -ne "  ${DIM}Press Enter...${NC}"; read -r
}

# ── Remove single JDK (from menu, per cursor position) ──
remove_single_jdk() {
  local v="${JDK_KEYS[$POS]}"
  local name="${JDK_NAMES[$POS]}"

  # Only allow removing installed JDKs (state=done)
  if [[ "${SELECTED[$POS]}" != "done" ]]; then
    warn "$name belum terinstall — hanya JDK [✓] yang bisa dihapus."
    sleep 1
    return
  fi

  clear 2>/dev/null || true
  echo ""
  echo -e "  ${WHT}${BLD}╔══════════════════════════════════════════════╗${NC}"
  echo -e "  ${WHT}${BLD}║${NC}     ${RED}${BLD}🗑  HAPUS ${name}${NC}"
  echo -e "  ${WHT}${BLD}╚══════════════════════════════════════════════╝${NC}"
  echo ""

  # Find the package name
  local pkg=""
  for prefix in "temurin-${v}-jdk" "openjdk-${v}-jdk" "openjdk-${v}-jdk-headless"; do
    if dpkg -l "$prefix" &>/dev/null 2>&1; then
      pkg="$prefix"
      break
    fi
  done

  if [[ -z "$pkg" ]]; then
    # Package not found via dpkg, try removing JVM dir directly
    local removed=false
    for jvm_dir in "/usr/lib/jvm/java-${v}-openjdk-amd64" "/usr/lib/jvm/temurin-${v}-jdk-amd64"; do
      if [[ -d "$jvm_dir" ]]; then
        echo -ne "  ${YLW}Remove $jvm_dir? [y/N]${NC} "
        read -r confirm
        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
          $SUDO rm -rf "$jvm_dir" && ok "Removed $jvm_dir"
          removed=true
        fi
      fi
    done
    if $removed; then
      SELECTED[$POS]="false"
      INSTALLED[$POS]="false"
      ok "$name dihapus."
    else
      warn "Package for $name not found."
    fi
  else
    echo -e "  ${DIM}Package:${NC} ${RED}$pkg${NC}"
    echo ""
    echo -ne "  ${YLW}Remove $pkg? [y/N]${NC} "
    read -r confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
      warn "Dibatalkan."
    else
      echo ""
      info "Removing $pkg..."
      if $SUDO apt-get remove -y -qq "$pkg" 2>/dev/null; then
        ok "Removed $pkg"
        # Clean JVM dir
        for jvm_dir in "/usr/lib/jvm/java-${v}-openjdk-amd64" "/usr/lib/jvm/temurin-${v}-jdk-amd64"; do
          [[ -d "$jvm_dir" ]] && $SUDO rm -rf "$jvm_dir" && ok "Cleaned $jvm_dir"
        done
        SELECTED[$POS]="false"
        INSTALLED[$POS]="false"
        # Jump cursor to first available
        POS=0
        while [[ $POS -lt ${#JDK_KEYS[@]} ]] && [[ "${SELECTED[$POS]}" == "done" ]]; do POS=$((POS + 1)); done
        [[ $POS -ge ${#JDK_KEYS[@]} ]] && POS=0
      else
        err "Failed to remove $pkg"
      fi
    fi
  fi

  echo ""
  echo -ne "  ${DIM}Press Enter...${NC}"; read -r
}

# Trigger uninstall
if $UNINSTALL; then
  uninstall_jdks
fi
