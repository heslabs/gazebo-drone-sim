#!/usr/bin/env bash
# Installs everything needed to build and run PX4 SITL + Gazebo on
# an x86_64 Ubuntu 20.04/22.04 machine.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config/env.sh"

echo "==> Checking architecture and OS"
ARCH="$(uname -m)"
if [[ "${ARCH}" != "x86_64" ]]; then
  echo "WARNING: this tutorial targets x86_64; detected '${ARCH}'. Continuing anyway."
fi

if ! command -v lsb_release >/dev/null 2>&1; then
  echo "lsb_release not found — this script expects an Ubuntu/Debian host." >&2
  exit 1
fi
echo "Detected: $(lsb_release -ds)"

echo "==> Installing base build tooling"
sudo apt-get update
sudo apt-get install -y \
  git curl wget build-essential cmake ninja-build \
  python3 python3-pip python3-venv \
  software-properties-common

echo "==> Adding the OSRF Gazebo apt repo (gazebo11/gz-harmonic aren't in Ubuntu's default repos)"
CODENAME="$(lsb_release -cs)"
sudo install -m 0755 -d /usr/share/keyrings
sudo wget -q https://packages.osrfoundation.org/gazebo.gpg -O /usr/share/keyrings/pkgs-osrf-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/pkgs-osrf-archive-keyring.gpg] http://packages.osrfoundation.org/gazebo/ubuntu-stable ${CODENAME} main" \
  | sudo tee /etc/apt/sources.list.d/gazebo-stable.list >/dev/null
sudo apt-get update

# Gazebo Classic 11 is only packaged for Ubuntu 20.04 (focal) and
# 22.04 (jammy). Ubuntu 24.04 (noble) dropped it — Gazebo (Ignition)
# Harmonic is the only option there, so we install Harmonic and
# switch the SITL target automatically.
case "${CODENAME}" in
  focal|jammy)
    echo "==> Installing Gazebo Classic 11 (the simulator PX4's default target uses)"
    sudo apt-get install -y gazebo11 libgazebo11-dev

    echo "==> Also installing Gazebo (Ignition) Harmonic (optional, newer target: gz_x500)"
    sudo apt-get install -y gz-harmonic || echo "gz-harmonic not available here — Gazebo Classic still works fine."
    ;;
  noble)
    echo "==> Ubuntu 24.04 detected: Gazebo Classic 11 is NOT packaged for noble."
    echo "    Installing Gazebo (Ignition) Harmonic instead and switching the SITL target."
    sudo apt-get install -y gz-harmonic

    ENV_FILE="${SCRIPT_DIR}/../config/env.sh"
    ENV_MK="${SCRIPT_DIR}/../config/env.mk"
    sed -i 's/^export PX4_SIM_TARGET=.*/export PX4_SIM_TARGET="${PX4_SIM_TARGET:-gz_x500}"/' "${ENV_FILE}"
    sed -i 's/^PX4_SIM_TARGET .*/PX4_SIM_TARGET ?= gz_x500/' "${ENV_MK}"
    echo "    config/env.sh and config/env.mk updated: PX4_SIM_TARGET=gz_x500"
    echo "    Note: 'make run-custom' (the custom obstacle_course.world) only supports"
    echo "    Gazebo Classic targets — it will refuse to run until you set"
    echo "    PX4_SIM_TARGET back to a gazebo-classic_* value on a 20.04/22.04 host."
    ;;
  *)
    echo "==> Unrecognized Ubuntu codename '${CODENAME}' — attempting Gazebo Classic 11 install anyway"
    sudo apt-get install -y gazebo11 libgazebo11-dev || \
      echo "gazebo11 not available for '${CODENAME}'. Try gz-harmonic manually: sudo apt-get install gz-harmonic"
    ;;
esac

echo "==> Python packages (MAVSDK, pymavlink, etc.) are installed separately"
echo "    into a project-local venv — run 'make venv' next (before 'make px4')."
echo "    We deliberately do NOT 'pip install --user' onto the system Python here:"
echo "    Ubuntu 24.04's system pip is externally-managed (PEP 668) and refuses"
echo "    that outright, and it also risks colliding with any conda/Anaconda"
echo "    environment active in your shell."

echo "==> Done. Next: 'make venv' to set up the Python environment, then 'make px4'."
