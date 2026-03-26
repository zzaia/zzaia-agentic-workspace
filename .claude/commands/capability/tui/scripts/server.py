#!/usr/bin/env python3
"""Textual TUI application with Unix socket bidirectional communication."""

import asyncio
import json
import os
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Optional

from textual.app import ComposeResult, RichPrintScreen
from textual.containers import Container, Vertical
from textual.widgets import Header, Footer, RichLog


@dataclass
class LogEntry:
    type: str
    message: str
    timestamp: datetime


class TUIApp(RichPrintScreen):
    TITLE = "ZZAIA TUI"
    BINDINGS = [("q", "quit", "Quit")]

    def __init__(self) -> None:
        super().__init__()
        self.log_widget: Optional[RichLog] = None
        self.log_entries: list[LogEntry] = []
        self.socket_server: Optional[asyncio.Server] = None
        self.socket_path = Path("/tmp/zzaia-tui.sock")
        self.pid_file = Path("/tmp/zzaia-tui.pid")
        self.color_map = {
            "info": "white",
            "success": "bold green",
            "error": "bold red",
            "warning": "yellow",
            "agent": "bold cyan",
            "tool": "yellow",
            "markdown": "white",
        }

    def compose(self) -> ComposeResult:
        yield Header()
        yield RichLog()
        yield Footer()

    async def on_mount(self) -> None:
        self.log_widget = self.query_one(RichLog)
        await self.setup_socket_server()
        self.write_pid_file()
        self.log_widget.write("[bold cyan]▶[/bold cyan] [cyan]ZZAIA TUI Started[/cyan]")

    async def setup_socket_server(self) -> None:
        self.socket_path.unlink(missing_ok=True)
        self.socket_server = await asyncio.start_unix_server(
            self.handle_client, str(self.socket_path)
        )

    async def handle_client(
        self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter
    ) -> None:
        try:
            data = await reader.read(4096)
            if not data:
                return
            payload = json.loads(data.decode("utf-8"))
            event_type = payload.get("type")

            if event_type == "shutdown":
                self.exit()
            elif event_type == "read":
                lines_count = payload.get("lines", 50)
                response_lines = [
                    {
                        "type": entry.type,
                        "message": entry.message,
                        "timestamp": entry.timestamp.isoformat(),
                    }
                    for entry in self.log_entries[-lines_count:]
                ]
                response = json.dumps({"lines": response_lines})
                writer.write(response.encode("utf-8"))
                await writer.drain()
            else:
                await self.process_event(payload)
                writer.write(b'{"status": "ok"}')
                await writer.drain()
        except Exception as e:
            if self.log_widget:
                self.log_widget.write(f"[bold red]❌ Socket error: {e}[/bold red]")
        finally:
            writer.close()
            await writer.wait_closed()

    async def process_event(self, payload: dict) -> None:
        event_type = payload.get("type", "info")
        message = payload.get("message", "")

        entry = LogEntry(type=event_type, message=message, timestamp=datetime.now())
        self.log_entries.append(entry)

        if not self.log_widget:
            return

        color = self.color_map.get(event_type, "white")

        if event_type == "success":
            formatted = f"[bold green]✅[/bold green] [bold green]{message}[/bold green]"
        elif event_type == "error":
            formatted = f"[bold red]❌[/bold red] [bold red]{message}[/bold red]"
        elif event_type == "warning":
            formatted = f"[yellow]⚠️[/yellow] [yellow]{message}[/yellow]"
        elif event_type == "agent":
            formatted = f"[bold cyan]▶[/bold cyan] [bold cyan]{message}[/bold cyan]"
        elif event_type == "tool":
            formatted = f"[yellow]⚙[/yellow] [yellow]{message}[/yellow]"
        elif event_type == "markdown":
            formatted = message
        else:
            formatted = message

        self.log_widget.write(formatted)

    def write_pid_file(self) -> None:
        self.pid_file.write_text(str(os.getpid()))

    def cleanup(self) -> None:
        self.socket_path.unlink(missing_ok=True)
        self.pid_file.unlink(missing_ok=True)
        if self.socket_server:
            self.socket_server.close()

    async def action_quit(self) -> None:
        self.cleanup()
        self.exit()


async def main() -> None:
    app = TUIApp()
    await app.run_async()


if __name__ == "__main__":
    asyncio.run(main())
