#!/usr/bin/env bash
# install-jdk.sh — Install all major JDK versions on Debian/Ubuntu
# Usage: curl -fsSL https://raw.githubusercontent.com/bianvigano/buildjar/main/install-jdk.sh | bash
#
# Installs: JDK 8, 11, 17, 21, 24 via apt (Temurin/OpenJDK)
# Sets JDK 21 as default. Also configures JAVA_HOME.

set -Eeuo pipefail

RED='\033[0;31m'; GRN='\033[0;32m'; YLW='\033[1;33m'; CYA='\033[0;36m'; NC='\033[0m'
ok()  { echo -e "${GRN}[✓]${NC} $*"; }
err() { echo -e "${RED}[✗]${NC} $*"; }
info(){ echo -e "${CYA}[•]${NC} $*"; }

# Check root
if [[ $EUID -ne 0 ]] && ! command -v sudo &>/dev/null; then
  err "Need root. Run: sudo bash install-jdk.sh"
  exit 1
fi
SUDO=""
[[ $EUID -ne 0 ]] && SUDO="sudo"

echo ""
echo "════════════════════════════════════════════"
echo "  JDK Multi-Version Installer"
echo "════════════════════════════════════════════"
echo ""

OS=""
if grep -qi "ubuntu" /etc/os-release 2>/dev/null; then OS="ubuntu"
elif grep -qi "debian" /etc/os-release 2>/dev/null; then OS="debian"
else
  err "Unsupported OS. Only Debian/Ubuntu supported."
  exit 1
fi

info "OS: $OS"

# ── Install JDKs ────────────────────────────────────────
JDK_VERSIONS=(8 11 17 21 24)
NEED_INSTALL=()

for v in "${JDK_VERSIONS[@]}"; do
  if command -v "javac" &>/dev/null && javac --version 2>&1 | grep -q "javac $v"; then
    ok "JDK $v already installed"
  else
    NEED_INSTALL+=("$v")
  fi
done

if [[ ${#NEED_INSTALL[@]} -eq 0 ]]; then
  echo ""
  ok "All JDK versions already installed."
  exit 0
fi

echo ""
info "Installing JDK: ${NEED_INSTALL[*]}"
echo ""

# Update package list if needed
$SUDO apt-get update -qq 2>/dev/null || true

# Try Temurin first (Eclipse Adoptium), fallback to OpenJDK
for v in "${NEED_INSTALL[@]}"; do
  echo ""
  info "Installing JDK $v..."

  # Temurin
  if apt-cache show "temurin-${v}-jdk" &>/dev/null 2>&1; then
    $SUDO apt-get install -y -qq "temurin-${v}-jdk" 2>/dev/null && { ok "JDK $v (Temurin)"; continue; }
  fi

  # OpenJDK
  if apt-cache show "openjdk-${v}-jdk" &>/dev/null 2>&1; then
    $SUDO apt-get install -y -qq "openjdk-${v}-jdk" 2>/dev/null && { ok "JDK $v (OpenJDK)"; continue; }
  fi

  # OpenJDK headless
  if apt-cache show "openjdk-${v}-jdk-headless" &>/dev/null 2>&1; then
    $SUDO apt-get install -y -qq "openjdk-${v}-jdk-headless" 2>/dev/null && { ok "JDK $v (OpenJDK headless)"; continue; }
  fi

  err "JDK $v: no package found in apt. Skipped."
done

echo ""

# ── Set Default JDK (21) ────────────────────────────────
info "Setting JDK 21 as default..."
for cmd in java javac jar; do
  if [[ -f "/usr/lib/jvm/java-21-openjdk-amd64/bin/$cmd" ]]; then
    $SUDO update-alternatives --set "$cmd" "/usr/lib/jvm/java-21-openjdk-amd64/bin/$cmd" 2>/dev/null || true
  elif [[ -f "/usr/lib/jvm/temurin-21-jdk-amd64/bin/$cmd" ]]; then
    $SUDO update-alternatives --set "$cmd" "/usr/lib/jvm/temurin-21-jdk-amd64/bin/$cmd" 2>/dev/null || true
  fi
done

# ── Set JAVA_HOME ────────────────────────────────────────
JAVA_HOME_PATH=""
for d in /usr/lib/jvm/java-21-openjdk-amd64 /usr/lib/jvm/temurin-21-jdk-amd64; do
  if [[ -d "$d" ]]; then
    JAVA_HOME_PATH="$d"
    break
  fi
done

if [[ -n "$JAVA_HOME_PATH" ]]; then
  for f in /etc/environment /etc/profile.d/jdk.sh; do
    :
  done

  if ! grep -q "JAVA_HOME" /etc/environment 2>/dev/null; then
    echo "JAVA_HOME=$JAVA_HOME_PATH" | $SUDO tee -a /etc/environment >/dev/null
    ok "JAVA_HOME=$JAVA_HOME_PATH added to /etc/environment"
  fi

  # Also create profile.d script
  $SUDO tee /etc/profile.d/jdk.sh >/dev/null <<EOF
export JAVA_HOME=$JAVA_HOME_PATH
export PATH=\$JAVA_HOME/bin:\$PATH
EOF
  $SUDO chmod 644 /etc/profile.d/jdk.sh
  ok "Created /etc/profile.d/jdk.sh"
fi

# ── Verify ───────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════"
echo "  Installed JDKs:"
echo "════════════════════════════════════════════"
echo ""

java --version 2>&1 || true
echo ""
echo "Available javac versions:"
update-alternatives --list javac 2>/dev/null || find /usr/lib/jvm -name javac -type f 2>/dev/null | sort || true

echo ""
echo "════════════════════════════════════════════"
echo "  ✓ Done. Restart shell or run:"
echo "    source /etc/profile.d/jdk.sh"
echo "════════════════════════════════════════════"
echo ""
