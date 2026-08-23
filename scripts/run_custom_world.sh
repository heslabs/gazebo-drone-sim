#!/usr/bin/env bash
# Launches PX4 SITL (Gazebo Classic, Iris model) using our custom
# obstacle_course.world instead of PX4's default empty world.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${PROJECT_ROOT}/config/env.sh"

if [[ ! -d "${PX4_DIR}" ]]; then
  echo "PX4-Autopilot not found at ${PX4_DIR}. Run 'make px4' first." >&2
  exit 1
fi

activate_venv
sanitize_conda_build_env

if [[ "${PX4_SIM_TARGET}" != gazebo-classic_* ]]; then
  echo "run_custom_world.sh only supports Gazebo Classic targets." >&2
  echo "Set PX4_SIM_TARGET=gazebo-classic_iris in config/env.sh and retry." >&2
  exit 1
fi

WORLD_SRC="${PROJECT_ROOT}/worlds/obstacle_course.world"
WORLD_DST="${PX4_DIR}/Tools/simulation/gazebo-classic/sitl_gazebo-classic/worlds/obstacle_course.world"

echo "==> Copying custom world into PX4's world directory"
mkdir -p "$(dirname "${WORLD_DST}")"
cp "${WORLD_SRC}" "${WORLD_DST}"

echo "==> Launching PX4 SITL with custom world 'obstacle_course'"
echo "    Home position fixed at lat=${PX4_HOME_LAT}, lon=${PX4_HOME_LON}, alt=${PX4_HOME_ALT}"
echo "    (matches demo/obstacle_course_mission.plan — see 'make demo-qgc' / README)"
cd "${PX4_DIR}"
PX4_SITL_WORLD=obstacle_course make px4_sitl "${PX4_SIM_TARGET}"
