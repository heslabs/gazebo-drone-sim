#!/usr/bin/env bash
# Launches PX4 SITL with the default Gazebo world and vehicle model
# defined in config/env.sh (PX4_SIM_TARGET).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config/env.sh"

if [[ ! -d "${PX4_DIR}" ]]; then
  echo "PX4-Autopilot not found at ${PX4_DIR}. Run 'make px4' first." >&2
  exit 1
fi

# `make px4_sitl` re-runs CMake/ninja incrementally, which uses Python
# (empy templating, etc.) even on a rebuild — activate our venv so
# that uses the same Python this was originally built against, not
# whatever python3 happens to be first on PATH (e.g. conda).
activate_venv

# Same reasoning as setup_px4.sh: strip any conda/Anaconda entries
# from PATH/CPATH/LIBRARY_PATH/LD_LIBRARY_PATH/etc. for this process,
# so a rebuild triggered by `make px4_sitl` can't pick up conda's
# headers/libs, and so Gazebo resolves its own libraries at runtime
# instead of any same-named ones conda might have on LD_LIBRARY_PATH.
sanitize_conda_build_env
resolve_sim_target

if [[ "${HEADLESS:-0}" == "1" ]]; then
  export HEADLESS=1
  echo "==> Running headless (no Gazebo GUI window)"
fi

echo "==> Launching PX4 SITL target '${PX4_SIM_TARGET}'"
echo "    MAVLink app port : udp://:${MAVLINK_UDP_PORT}"
echo "    MAVLink GCS port : udp://:${MAVLINK_GCS_PORT}"
echo "    (Ctrl-C to stop the simulation)"

cd "${PX4_DIR}"
make px4_sitl "${PX4_SIM_TARGET}"
