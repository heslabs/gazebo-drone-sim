#!/usr/bin/env python3
"""
Simple scripted flight: connect to PX4 SITL, arm, take off, hover,
then land. Run this while 'make run' (or 'make run-custom') is
already up in another terminal.

Usage:
    python3 scripts/takeoff_demo.py
"""
import asyncio
import os

from mavsdk import System

MAVLINK_UDP_PORT = os.environ.get("MAVLINK_UDP_PORT", "14540")
HOVER_ALTITUDE_M = 5.0
HOVER_SECONDS = 10


async def main():
    drone = System()
    print(f"Connecting to PX4 SITL on udp://:{MAVLINK_UDP_PORT} ...")
    await drone.connect(system_address=f"udp://:{MAVLINK_UDP_PORT}")

    print("Waiting for drone to connect...")
    async for state in drone.core.connection_state():
        if state.is_connected:
            print("-- Connected to drone!")
            break

    print("Waiting for global position + home position lock...")
    async for health in drone.telemetry.health():
        if health.is_global_position_ok and health.is_home_position_ok:
            print("-- Global position estimate OK")
            break

    print("-- Arming")
    await drone.action.arm()

    print(f"-- Taking off to ~{HOVER_ALTITUDE_M} m")
    await drone.action.set_takeoff_altitude(HOVER_ALTITUDE_M)
    await drone.action.takeoff()

    print(f"-- Hovering for {HOVER_SECONDS} s")
    await asyncio.sleep(HOVER_SECONDS)

    print("-- Landing")
    await drone.action.land()

    print("-- Waiting for landing + disarm to complete")
    async for in_air in drone.telemetry.in_air():
        if not in_air:
            print("-- Landed")
            break

    print("Demo complete.")


if __name__ == "__main__":
    asyncio.run(main())
