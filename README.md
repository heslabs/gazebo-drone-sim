# Drone Simulator Tutorial — PX4 SITL + Gazebo (x86 Linux)

This project gives you a one-command way to stand up a drone flight
simulator on an x86_64 Linux PC using:

- **PX4 Autopilot** (SITL — Software In The Loop) — the flight control
  stack that actually "flies" the drone
- **Gazebo** (Gazebo Classic 11 by default, switchable to Gazebo/Ignition
  Harmonic) — the 3D physics simulator that renders the world and the
  vehicle
- **MAVSDK / MAVLink** — for talking to the simulated drone from scripts
  or a ground control station

Everything is wired up through a `Makefile` so you don't have to
remember long command lines.

## Why PX4 + Gazebo?

PX4's SITL target ships a ready-made Gazebo drone model (`iris` /
`x500`) with a full flight controller running in the loop, so you get
a realistic, controllable multirotor without writing any control code
yourself. It's the same stack used on real PX4-powered hardware, so
what you learn transfers directly.

## Project layout

```
drone-sim-tutorial/
├── Makefile                  # entry point: make install, make venv, make run, ...
├── README.md                 # this file
├── scripts/
│   ├── install_deps.sh       # installs Gazebo, PX4 build deps (system/apt level)
│   ├── setup_venv.sh         # creates the project's Python venv + MAVSDK/pymavlink
│   ├── setup_px4.sh          # clones + builds PX4-Autopilot (uses the venv)
│   ├── run_sim.sh            # launches PX4 SITL + Gazebo
│   ├── run_custom_world.sh   # launches SITL with the custom world below, fixed home position
│   ├── make_qgc_plan.py      # generates demo/obstacle_course_mission.plan
│   └── takeoff_demo.py       # MAVSDK script: arm, takeoff, hover, land
├── worlds/
│   └── obstacle_course.world # a simple custom Gazebo world (pylons + landing pad)
├── demo/
│   └── obstacle_course_mission.plan  # QGroundControl mission matching the world above
├── config/
│   ├── env.sh                # environment variables + activate_venv(), sourced by scripts
│   └── env.mk                # Make-syntax mirror of env.sh, included by the Makefile
└── .venv/                    # created by `make venv` — the project's isolated Python env
```

## Prerequisites

- Ubuntu 20.04, 22.04, or 24.04 on x86_64 (native or VM with 3D
  acceleration passthrough — Gazebo needs GPU access to render at
  usable speed)
- ~15 GB free disk, sudo privileges, internet access
- Python 3.8+ (via `python3-venv`, installed automatically by `make install`)
- A conda/Anaconda environment active in your shell (a `(base)` prompt
  or similar) is fine — this project's scripts isolate their own
  Python/build environment automatically. See
  [Python environment](#python-environment) below for details.

## Quick start

```bash
git clone <this-project-or-copy-the-folder>
cd drone-sim-tutorial

make install      # installs system deps: Gazebo, PX4 build toolchain
make venv           # creates .venv and installs MAVSDK/pymavlink/PX4 Python deps into it
make px4              # clones PX4-Autopilot and does the first SITL build (runs `make venv` too if skipped)
make run                # launches Gazebo with the PX4 SITL drone (Iris)

# in a second terminal, once the sim is up:
make demo              # runs a scripted arm -> takeoff -> hover -> land
```

## Python environment

Everything Python-related — PX4's own build-time dependencies
(`empy`, `jinja2`, etc.), and MAVSDK/pymavlink for `takeoff_demo.py`
— installs into a project-local virtual environment at `.venv/`,
created by `make venv` (or automatically as a dependency of
`make px4`). `scripts/*.sh` activate it automatically via the
`activate_venv` helper in `config/env.sh`; you don't need to `source`
anything by hand for normal `make` usage.

This is deliberate, not just tidiness:

- **Ubuntu 24.04's system pip is "externally managed"** (PEP 668) and
  refuses `pip install --user` outright. A venv sidesteps that
  restriction cleanly instead of forcing system packages.
- **Conda/Anaconda environments can shadow `python3`/`pip`** and leak
  their own include/library search paths into native builds, which is
  a common source of confusing version-mismatch errors in unrelated
  tools further down the pipeline (protobuf/Gazebo header conflicts
  being a notorious example). `scripts/setup_venv.sh` deliberately
  builds the venv from `/usr/bin/python3` (Ubuntu's own interpreter),
  not whatever `python3` resolves to on `PATH`. On top of that, every
  build/run script also calls `sanitize_conda_build_env` (see
  `config/env.sh`), which strips conda/Anaconda entries out of
  `PATH`/`CPATH`/`LIBRARY_PATH`/etc. for its own process — so you
  don't need to `conda deactivate` in your interactive shell for
  `make` commands in this project to work correctly.

To inspect or use the venv directly:

```bash
source .venv/bin/activate
python -c "import mavsdk; print(mavsdk.__file__)"
deactivate
```

To fly the custom obstacle-course world instead of the default one:

```bash
make run-custom
```

To tear down build artifacts:

```bash
make clean
```

## What each `make` target does

| Target         | Action |
|-----------------|--------|
| `make install`  | Runs `scripts/install_deps.sh` — apt packages, Gazebo (system level, no Python) |
| `make venv`      | Runs `scripts/setup_venv.sh` — creates `.venv` and installs MAVSDK/pymavlink/PX4 Python deps into it |
| `make px4`       | Depends on `venv`; runs `scripts/setup_px4.sh` — clones PX4-Autopilot, `git submodule update`, first SITL build |
| `make run`       | Runs `scripts/run_sim.sh` — `make px4_sitl gazebo-classic_iris` inside PX4-Autopilot (venv activated) |
| `make run-custom`| Runs `scripts/run_custom_world.sh` — same, but loads `worlds/obstacle_course.world` with a fixed home position |
| `make qgc-plan`  | Runs `scripts/make_qgc_plan.py` — (re)generates `demo/obstacle_course_mission.plan` |
| `make demo`      | Runs `scripts/takeoff_demo.py` with the venv's Python, over MAVSDK against `udp://:14540` |
| `make clean`     | Removes PX4 build output only (keeps the source clone and the venv) |
| `make distclean` | Removes the cloned `PX4-Autopilot` directory AND `.venv` |
| `make help`      | Prints target descriptions |

## QGC + Gazebo demo: fly a mission through the obstacle course

This ties together the custom `obstacle_course.world` and
QGroundControl into one scripted flight: takeoff, weave through the
pylons, and land precisely on the raised pad — flown from a QGC
mission upload, not a manual joystick.

**Why this works reliably:** `run_custom_world.sh` pins PX4's SITL
home position to a fixed lat/lon (`PX4_HOME_LAT`/`PX4_HOME_LON`/
`PX4_HOME_ALT` in `config/env.sh`), and `demo/obstacle_course_mission.plan`
was generated (`scripts/make_qgc_plan.py`) from those exact same
coordinates. So the mission's absolute GPS waypoints always line up
with the pylons' fixed positions in the Gazebo world — no manual
alignment needed.

1. **Install QGroundControl** if you haven't — see the install steps
   above (or ask me again if you need them re-shown).
2. **Launch the sim with the obstacle course:**
   ```bash
   make run-custom
   ```
   Wait for the `pxh>` prompt and the Gazebo window showing the Iris
   drone near the three pylons and the yellow landing pad.
3. **Launch QGroundControl** and let it auto-connect (see the QGC
   setup steps above). You should see the vehicle appear on the map
   near the obstacle course's home position.
4. **Load the mission:** in QGC, go to the **Plan** view (top toolbar)
   → **File** → **Open** → select `demo/obstacle_course_mission.plan`
   from this project. You'll see 5 waypoints plotted: takeoff, a
   weave right of the center pylon, a weave left of it, an approach
   over the landing pad, and a landing marker on the pad itself.
5. **Upload the mission:** click **Upload Required** (or the upload
   icon) in the Plan view to send it to the SITL vehicle over MAVLink.
6. **Fly it:** switch to the **Fly** view, then arm and start the
   mission — either the **Start Mission** slider QGC shows once armed,
   or from the `pxh>` shell:
   ```
   commander arm
   commander mode auto:mission
   ```
   Watch the Gazebo window: the Iris should climb, weave between the
   pylons, fly out to the landing pad, and land on it autonomously.

**Customizing it:** edit the waypoint offsets (in meters, north/east
of home) near the top of `scripts/make_qgc_plan.py`, then run
`make qgc-plan` to regenerate the `.plan` file. If you also change
`PX4_HOME_LAT`/`PX4_HOME_LON`/`PX4_HOME_ALT` in `config/env.sh`,
re-run `make qgc-plan` afterward too — the generator reads those same
defaults, so the mission stays aligned with wherever you've told PX4
to spawn.

## Manual flying (optional)

Once `make run` is up, PX4 SITL exposes a MAVLink stream on UDP
`14540` and a pxh> shell in the terminal that launched it. You can:

- Type `commander takeoff` in the `pxh>` shell to take off manually
- Connect **QGroundControl** (download separately) — it auto-detects
  SITL on `udp://:14550` and gives you a joystick-style flight view
- Connect any MAVSDK/pymavlink script to `udp://:14540`

## Switching to Gazebo (Ignition) Harmonic

PX4 also supports the newer Gazebo (formerly "Ignition") simulator.
If you'd rather use that instead of Gazebo Classic, edit
`config/env.sh` and change:

```bash
export PX4_SIM_TARGET="gz_x500"     # was: gazebo-classic_iris
```

then re-run `make run`. `scripts/install_deps.sh` installs both
Gazebo Classic 11 and Gazebo Harmonic so either path works.

## Troubleshooting

- Note: `run_custom_world.sh` (the `obstacle_course.world` /
  QGC demo) deliberately still *requires* a real Classic target and
  will refuse to run without one — that demo genuinely needs a Classic
  world file, so on Ubuntu 24.04+ it isn't available; run it on 20.04
  or 22.04 instead.
- **Port already in use**: an old SITL/Gazebo instance is still
  running — `pkill -f px4` and `pkill -f gzserver` then retry.
