from __future__ import annotations

import argparse
import logging
import time

import dronecan
import dronecan.driver.slcan as slcan
from dronecan import uavcan
from dronecan.app.node_monitor import NodeMonitor


def patch_slcan_init_skip_f() -> None:
    ack_timeout = slcan.ACK_TIMEOUT
    ack = slcan.ACK
    nack = slcan.NACK
    driver_error = slcan.DriverError

    def patched_init_adapter(conn, bitrate):
        def wait_for_ack():
            conn.timeout = ack_timeout
            while True:
                byte = conn.read(1)
                if not byte:
                    raise driver_error("SLCAN ACK timeout")
                if byte == nack:
                    raise driver_error("SLCAN NACK in response")
                if byte == ack:
                    break

        def send_command(cmd):
            conn.write(cmd + b"\r")

        speed_code = {
            1000000: 8,
            800000: 7,
            500000: 6,
            250000: 5,
            125000: 4,
            100000: 3,
            50000: 2,
            20000: 1,
            10000: 0,
        }[bitrate if bitrate is not None else slcan.DEFAULT_BITRATE]

        retries = 3
        while True:
            try:
                send_command(b"")
                try:
                    wait_for_ack()
                except driver_error:
                    pass
                time.sleep(0.1)
                conn.flushInput()

                send_command(b"C")
                try:
                    wait_for_ack()
                except driver_error:
                    pass

                send_command(("S%d" % speed_code).encode())
                conn.flush()
                wait_for_ack()

                send_command(b"O")
                conn.flush()
                wait_for_ack()
            except Exception:
                if retries <= 0:
                    raise
                retries -= 1
                time.sleep(0.2)
            else:
                break

        time.sleep(0.1)
        conn.flushInput()

    slcan._init_adapter = patched_init_adapter


patch_slcan_init_skip_f()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Open the local SLCAN adapter without issuing the unsupported F command."
    )
    parser.add_argument("--port", default="COM9")
    parser.add_argument("--baudrate", type=int, default=115200)
    parser.add_argument("--bitrate", type=int, default=1000000)
    parser.add_argument("--node-id", type=int, default=120)
    parser.add_argument("--observe-sec", type=float, default=8.0)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )

    node = dronecan.make_node(
        args.port,
        baudrate=args.baudrate,
        bitrate=args.bitrate,
        node_id=args.node_id,
    )
    monitor = NodeMonitor(node)
    seen_status: dict[int, int] = {}

    def on_node_status(event) -> None:
        source_node_id = event.transfer.source_node_id
        seen_status[source_node_id] = seen_status.get(source_node_id, 0) + 1

    node.add_handler(uavcan.protocol.NodeStatus, on_node_status)
    started = time.monotonic()

    try:
        while time.monotonic() - started < args.observe_sec:
            try:
                node.spin(0.1)
            except Exception as ex:
                print("SPIN_ERR", type(ex).__name__, ex)
                time.sleep(0.1)

        entries = sorted(
            monitor.find_all(lambda entry: True),
            key=lambda entry: entry.node_id,
        )
        print("NODE_STATUS_COUNTS", seen_status)
        print("ENTRY_COUNT", len(entries))
        for entry in entries:
            status = entry.status
            info = entry.info
            name = ""
            if info is not None:
                name = bytes(info.name).decode("utf-8", errors="ignore").rstrip("\x00")
            print(
                "NODE",
                entry.node_id,
                "uptime",
                int(status.uptime_sec) if status else None,
                "health",
                int(status.health) if status else None,
                "mode",
                int(status.mode) if status else None,
                "vssc",
                int(status.vendor_specific_status_code) if status else None,
                "name",
                name,
            )
    finally:
        node.close()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
