#!/usr/bin/env bash
# Creates a project-local Python virtual environment at ${VENV_DIR}
# and installs the Python packages this tutorial needs into it:
# MAVSDK/pymavlink for scripting the drone, plus PX4's own build-time
# Python dependencies (empy, jinja2, etc. — see PX4's
# Tools/setup/requirements.txt, which setup_px4.sh also installs into
# this same venv once PX4-Autopilot is cloned).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config/env.sh"

# Deliberately locate the SYSTEM python3, not whatever is first on
# PATH. If a conda/Anaconda environment is active (a "(base)" or
# similar shell prompt), `python3` on PATH resolves to conda's
# interpreter — building the venv from that would just relocate the
# same contamination problem rather than fix it. /usr/bin/python3 is
# Ubuntu's own interpreter and is what apt's python3-venv package
# targets.
if [[ -x /usr/bin/python3 ]]; then
  SYSTEM_PYTHON="/usr/bin/python3"
else
  SYSTEM_PYTHON="$(command -v python3)"
  echo "==> WARNING: /usr/bin/python3 not found; falling back to '${SYSTEM_PYTHON}'."
  echo "    If a conda/Anaconda environment is active in this shell, run"
  echo "    'conda deactivate' first and re-run 'make venv', or this venv"
  echo "    may inherit the same environment conflicts it's meant to avoid."
fi
echo "==> Using ${SYSTEM_PYTHON} ($(${SYSTEM_PYTHON} --version 2>&1)) to create the venv"

if [[ -d "${VENV_DIR}" ]]; then
  echo "==> Venv already exists at ${VENV_DIR} — reusing it"
else
  echo "==> Creating venv at ${VENV_DIR}"
  "${SYSTEM_PYTHON}" -m venv "${VENV_DIR}"
fi

# shellcheck disable=SC1091
source "${VENV_DIR}/bin/activate"

echo "==> Upgrading pip inside the venv"
python -m pip install --upgrade pip

echo "==> Installing MAVSDK / pymavlink and PX4 build-time Python dependencies"
python -m pip install --upgrade \
  mavsdk \
  pymavlink \
  empy==3.3.4 \
  pyros-genmsg \
  jinja2 \
  packaging \
  toml \
  numpy \
  future

echo "==> Venv ready at ${VENV_DIR}"
echo "    Activate it manually with: source ${VENV_DIR}/bin/activate"
echo "    (scripts/*.sh in this project activate it automatically via"
echo "    config/env.sh's activate_venv function — no manual step needed"
echo "    for 'make px4', 'make run', or 'make demo'.)"
