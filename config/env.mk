# Make-syntax mirror of config/env.sh, used only by the Makefile itself.
# Keep values here in sync with config/env.sh — scripts/*.sh source
# env.sh directly, so this file only affects `make` output/echoing.

PX4_DIR       ?= $(PROJECT_ROOT)/PX4-Autopilot
PX4_SIM_TARGET ?= gazebo-classic_iris
PX4_VERSION   ?= v1.15.0
VENV_DIR      ?= $(PROJECT_ROOT)/.venv
