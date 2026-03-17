#!/usr/bin/env python3
"""Unix socket client for communicating with TUI server."""

import asyncio
import argparse
import json
import sys
from pathlib import Path
from typing import Optional


async def connect_and_send(
    socket_path: str, payload: dict
) -> Optional[dict]:
    try:
        reader, writer = await asyncio.open_unix_connection(socket_path)
    except FileNotFoundError:
        print(f"Error: Socket file not found at {socket_path}", file=sys.stderr)
        return None
    except ConnectionRefusedError:
        print(f"Error: TUI server not running at {socket_path}", file=sys.stderr)
        return None

    try:
        writer.write(json.dumps(payload).encode("utf-8"))
        await writer.drain()

        response_data = await reader.read(8192)
        if not response_data:
            return None

        response = json.loads(response_data.decode("utf-8"))
        return response
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        return None
    finally:
        writer.close()
        await writer.wait_closed()


async def write_event(
    socket_path: str, event_type: str, message: str
) -> None:
    payload = {"type": event_type, "message": message}
    response = await connect_and_send(socket_path, payload)
    if response:
        print("Event sent successfully")


async def read_logs(socket_path: str, lines: int) -> None:
    payload = {"type": "read", "lines": lines}
    response = await connect_and_send(socket_path, payload)
    if response and "lines" in response:
        for entry in response["lines"]:
            timestamp = entry.get("timestamp", "").split("T")[-1][:8]
            event_type = entry.get("type", "unknown")
            message = entry.get("message", "")
            print(f"[{timestamp}] [{event_type:8}] {message}")


async def shutdown(socket_path: str) -> None:
    payload = {"type": "shutdown"}
    response = await connect_and_send(socket_path, payload)
    if response:
        print("Shutdown signal sent")


async def main() -> None:
    parser = argparse.ArgumentParser(
        description="Unix socket client for TUI server"
    )
    parser.add_argument(
        "--socket", default="/tmp/zzaia-tui.sock", help="Socket path"
    )
    parser.add_argument("--type", help="Event type or command")
    parser.add_argument("--message", help="Event message")
    parser.add_argument("--lines", type=int, default=50, help="Number of lines to read")
    parser.add_argument(
        "--shutdown", action="store_true", help="Send shutdown signal"
    )

    args = parser.parse_args()
    socket_path = args.socket

    if args.shutdown:
        await shutdown(socket_path)
    elif args.type and args.type == "read":
        await read_logs(socket_path, args.lines)
    elif args.type and args.message:
        await write_event(socket_path, args.type, args.message)
    else:
        parser.print_help()


if __name__ == "__main__":
    asyncio.run(main())
