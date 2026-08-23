SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

PROJECT_ROOT := $(shell pwd)
include config/env.mk
export

.PHONY: help install venv px4 run run-custom qgc-plan demo clean distclean

help: ## Show this help
	@echo "Drone Simulator Tutorial — PX4 SITL + Gazebo"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' Makefile | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

install: ## Install system deps: Gazebo, PX4 build toolchain
	@bash scripts/install_deps.sh

venv: ## Create the project's Python venv and install MAVSDK/pymavlink/PX4 Python deps into it
	@bash scripts/setup_venv.sh

px4: venv ## Clone + build PX4-Autopilot for SITL (target set in config/env.sh)
	@bash scripts/setup_px4.sh

run: ## Launch PX4 SITL + Gazebo with the default world/vehicle
	@bash scripts/run_sim.sh

run-custom: ## Launch PX4 SITL + Gazebo with worlds/obstacle_course.world (fixed home position for the QGC demo)
	@bash scripts/run_custom_world.sh

qgc-plan: ## (Re)generate demo/obstacle_course_mission.plan to load in QGroundControl
	@python3 scripts/make_qgc_plan.py

demo: ## Run scripted arm -> takeoff -> hover -> land over MAVSDK (needs `make run` active)
	@if [ ! -x "$(VENV_DIR)/bin/python" ]; then \
		echo "Venv not found at $(VENV_DIR). Run 'make venv' first." >&2; \
		exit 1; \
	fi
	@"$(VENV_DIR)/bin/python" scripts/takeoff_demo.py

clean: ## Remove PX4 build output only (keeps the cloned source and venv)
	@if [ -d "$(PX4_DIR)/build" ]; then \
		echo "==> Removing $(PX4_DIR)/build"; \
		rm -rf "$(PX4_DIR)/build"; \
	else \
		echo "Nothing to clean."; \
	fi

distclean: ## Remove the cloned PX4-Autopilot directory AND the venv
	@if [ -d "$(PX4_DIR)" ]; then \
		echo "==> Removing $(PX4_DIR)"; \
		rm -rf "$(PX4_DIR)"; \
	fi
	@if [ -d "$(VENV_DIR)" ]; then \
		echo "==> Removing $(VENV_DIR)"; \
		rm -rf "$(VENV_DIR)"; \
	fi
