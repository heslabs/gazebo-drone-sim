#!/usr/bin/env python3
"""
Generates a QGroundControl .plan mission file whose waypoints line up
with worlds/obstacle_course.world's pylons and landing pad, using a
FIXED PX4 SITL home position (see PX4_HOME_LAT/LON/ALT below and in
config/env.sh — run_custom_world.sh exports these before launching
SITL, so this alignment is deterministic every run).

Mission: takeoff -> weave right of the center pylon -> weave left of
it -> approach and land on the raised landing pad.

Usage:
    python3 scripts/make_qgc_plan.py
    (writes demo/obstacle_course_mission.plan)
"""
import json
import math
from pathlib import Path

# Must match PX4_HOME_LAT / PX4_HOME_LON / PX4_HOME_ALT in config/env.sh.
HOME_LAT = 47.397742
HOME_LON = 8.545594
HOME_ALT = 488.0

MISSION_ALT_REL_M = 10.0  # cruise altitude, relative to home
OUTPUT_PATH = Path(__file__).resolve().parent.parent / "demo" / "obstacle_course_mission.plan"


def offset_to_latlon(north_m: float, east_m: float, home_lat=HOME_LAT, home_lon=HOME_LON):
    """Flat-earth approximation — accurate to well under a meter at
    this scale (a few tens of meters from home), which is all a demo
    mission over a Gazebo world needs."""
    m_per_deg_lat = 111320.0
    m_per_deg_lon = 111320.0 * math.cos(math.radians(home_lat))
    lat = home_lat + (north_m / m_per_deg_lat)
    lon = home_lon + (east_m / m_per_deg_lon)
    return round(lat, 7), round(lon, 7)


def simple_item(command, params, do_jump_id, frame=3, autocontinue=True):
    return {
        "AMSLAltAboveTerrain": None,
        "Altitude": params[6] if len(params) > 6 and params[6] is not None else MISSION_ALT_REL_M,
        "AltitudeMode": 1,
        "autoContinue": autocontinue,
        "command": command,
        "doJumpId": do_jump_id,
        "frame": frame,
        "params": params,
        "type": "SimpleItem",
    }


def build_mission():
    items = []
    do_jump_id = 1

    # 1. Takeoff straight up to cruise altitude at home.
    lat, lon = offset_to_latlon(0, 0)
    items.append(simple_item(
        command=22,  # MAV_CMD_NAV_TAKEOFF
        params=[0, 0, 0, None, lat, lon, MISSION_ALT_REL_M],
        do_jump_id=do_jump_id,
    ))
    do_jump_id += 1

    # 2. Weave right of the center pylon (between pylon_1 and pylon_2).
    lat, lon = offset_to_latlon(5, 2)
    items.append(simple_item(
        command=16,  # MAV_CMD_NAV_WAYPOINT
        params=[0, 2, 0, None, lat, lon, MISSION_ALT_REL_M],
        do_jump_id=do_jump_id,
    ))
    do_jump_id += 1

    # 3. Weave left of the center pylon (between pylon_1 and pylon_3).
    lat, lon = offset_to_latlon(5, -2)
    items.append(simple_item(
        command=16,  # MAV_CMD_NAV_WAYPOINT
        params=[0, 2, 0, None, lat, lon, MISSION_ALT_REL_M],
        do_jump_id=do_jump_id,
    ))
    do_jump_id += 1

    # 4. Approach directly above the landing pad.
    lat, lon = offset_to_latlon(10, 0)
    items.append(simple_item(
        command=16,  # MAV_CMD_NAV_WAYPOINT
        params=[0, 2, 0, None, lat, lon, MISSION_ALT_REL_M],
        do_jump_id=do_jump_id,
    ))
    do_jump_id += 1

    # 5. Land on the pad.
    lat, lon = offset_to_latlon(10, 0)
    items.append(simple_item(
        command=21,  # MAV_CMD_NAV_LAND
        params=[0, 0, 0, None, lat, lon, 0],
        do_jump_id=do_jump_id,
    ))

    home_lat, home_lon = offset_to_latlon(0, 0)
    plan = {
        "fileType": "Plan",
        "geoFence": {"circles": [], "polygons": [], "version": 2},
        "groundStation": "QGroundControl",
        "mission": {
            "cruiseSpeed": 5,
            "firmwareType": 12,  # PX4
            "globalPlanAltitudeMode": 1,
            "hoverSpeed": 3,
            "items": items,
            "plannedHomePosition": [home_lat, home_lon, HOME_ALT],
            "vehicleType": 2,  # multirotor
            "version": 2,
        },
        "rallyPoints": {"points": [], "version": 2},
        "version": 1,
    }
    return plan


def main():
    plan = build_mission()
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    with open(OUTPUT_PATH, "w") as f:
        json.dump(plan, f, indent=4)
    print(f"Wrote {OUTPUT_PATH}")
    print(f"Home: lat={HOME_LAT}, lon={HOME_LON}, alt={HOME_ALT}")
    print("Load this in QGroundControl via Plan view -> File -> Open.")


if __name__ == "__main__":
    main()
