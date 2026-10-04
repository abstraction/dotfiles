#!/usr/bin/env python3
"""
Workrave D-Bus monitor and action helper for Omarchy shell plugin.
Streams state changes as JSON lines to stdout and handles control actions.
"""

import sys
import json
import dbus
import dbus.mainloop.glib
from gi.repository import GLib

BUS_NAME = "org.workrave.Workrave"
CORE_PATH = "/org/workrave/Workrave/Core"
CORE_IFACE = "org.workrave.CoreInterface"
UI_PATH = "/org/workrave/Workrave/UI"
UI_IFACE = "org.workrave.AppletInterface"


def execute_action(action: str):
    """Execute a D-Bus action against Workrave and exit."""
    try:
        bus = dbus.SessionBus()
        if action.startswith("mode_"):
            mode = action[len("mode_"):]
            core_obj = bus.get_object(BUS_NAME, CORE_PATH)
            core = dbus.Interface(core_obj, CORE_IFACE)
            core.SetOperationMode(mode)
            print(f"Set mode to {mode}")
        elif action in ("open", "preferences", "restbreak", "exercises", "statistics", "about", "quit"):
            ui_obj = bus.get_object(BUS_NAME, UI_PATH)
            ui = dbus.Interface(ui_obj, UI_IFACE)
            menu_action = f"workrave.{action}"
            ui.MenuAction(menu_action)
            print(f"Executed {menu_action}")
        elif action == "skip_microbreak":
            core_obj = bus.get_object(BUS_NAME, CORE_PATH)
            core = dbus.Interface(core_obj, CORE_IFACE)
            core.SkipBreak("microbreak")
            print("Skipped microbreak")
        elif action == "postpone_microbreak":
            core_obj = bus.get_object(BUS_NAME, CORE_PATH)
            core = dbus.Interface(core_obj, CORE_IFACE)
            core.PostponeBreak("microbreak")
            print("Postponed microbreak")
        elif action == "skip_restbreak":
            core_obj = bus.get_object(BUS_NAME, CORE_PATH)
            core = dbus.Interface(core_obj, CORE_IFACE)
            core.SkipBreak("restbreak")
            print("Skipped restbreak")
        elif action == "postpone_restbreak":
            core_obj = bus.get_object(BUS_NAME, CORE_PATH)
            core = dbus.Interface(core_obj, CORE_IFACE)
            core.PostponeBreak("restbreak")
            print("Postponed restbreak")
        else:
            print(f"Unknown action: {action}", file=sys.stderr)
            sys.exit(1)
    except Exception as e:
        print(f"Error executing action {action}: {e}", file=sys.stderr)
        sys.exit(1)


class WorkraveMonitor:
    def __init__(self):
        dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
        self.bus = dbus.SessionBus()
        self.loop = GLib.MainLoop()
        self.is_connected = False
        self.core_iface = None
        self.ui_iface = None
        self.timer_receiver = None
        self.mode_receiver = None
        self.last_micro = None
        self.last_rest = None
        self.last_daily = None

        self.bus.watch_name_owner(BUS_NAME, self._on_name_owner_changed)

    def _on_name_owner_changed(self, new_owner):
        if new_owner:
            self._connect()
        else:
            self._disconnect()

    def _connect(self):
        try:
            core_obj = self.bus.get_object(BUS_NAME, CORE_PATH)
            self.core_iface = dbus.Interface(core_obj, CORE_IFACE)
            ui_obj = self.bus.get_object(BUS_NAME, UI_PATH)
            self.ui_iface = dbus.Interface(ui_obj, UI_IFACE)

            if not self.timer_receiver:
                self.timer_receiver = self.bus.add_signal_receiver(
                    self._on_timers_updated,
                    signal_name="TimersUpdated",
                    dbus_interface=UI_IFACE
                )
            if not self.mode_receiver:
                self.mode_receiver = self.bus.add_signal_receiver(
                    self._on_mode_changed,
                    signal_name="OperationModeChanged",
                    dbus_interface=CORE_IFACE
                )

            self.is_connected = True
            self._emit_current_state()
        except Exception as e:
            self.is_connected = False
            self._emit_not_running(str(e))

    def _disconnect(self):
        self.is_connected = False
        self.core_iface = None
        self.ui_iface = None
        self.last_micro = None
        self.last_rest = None
        self.last_daily = None
        self._emit_not_running()

    def _emit_not_running(self, err=""):
        payload = {
            "running": False,
            "error": err
        }
        print(json.dumps(payload), flush=True)

    def _on_mode_changed(self, mode):
        if self.last_micro and self.last_rest and self.last_daily:
            self._on_timers_updated(self.last_micro, self.last_rest, self.last_daily)
        else:
            self._emit_current_state()

    def _on_timers_updated(self, micro, rest, daily):
        self.last_micro = micro
        self.last_rest = rest
        self.last_daily = daily
        self._emit_snapshot(micro, rest, daily)

    def _emit_current_state(self):
        if not self.is_connected or not self.core_iface:
            self._emit_not_running()
            return
        try:
            mode = str(self.core_iface.GetOperationMode())
            micro_running = bool(self.core_iface.IsTimerRunning("microbreak"))
            idle_sec = int(self.core_iface.GetTimerIdle("microbreak"))
            micro_rem = int(self.core_iface.GetTimerRemaining("microbreak"))
            micro_elapsed = int(self.core_iface.GetTimerElapsed("microbreak"))
            rest_rem = int(self.core_iface.GetTimerRemaining("restbreak"))
            rest_elapsed = int(self.core_iface.GetTimerElapsed("restbreak"))
            daily_rem = int(self.core_iface.GetTimerRemaining("dailylimit"))
            daily_elapsed = int(self.core_iface.GetTimerElapsed("dailylimit"))
            micro_state = str(self.core_iface.GetBreakState("microbreak"))
            rest_state = str(self.core_iface.GetBreakState("restbreak"))

            payload = {
                "running": True,
                "mode": mode,
                "user_active": micro_running,
                "idle_seconds": idle_sec,
                "micro": {
                    "text": self._format_seconds(micro_rem),
                    "remaining": max(0, micro_rem),
                    "limit": max(0, micro_rem + micro_elapsed),
                    "elapsed": micro_elapsed,
                    "state": micro_state
                },
                "rest": {
                    "text": self._format_seconds(rest_rem),
                    "remaining": max(0, rest_rem),
                    "limit": max(0, rest_rem + rest_elapsed),
                    "elapsed": rest_elapsed,
                    "state": rest_state
                },
                "daily": {
                    "text": self._format_seconds(daily_rem),
                    "remaining": max(0, daily_rem),
                    "limit": max(0, daily_rem + daily_elapsed),
                    "elapsed": daily_elapsed,
                    "state": "none"
                }
            }
            print(json.dumps(payload), flush=True)
        except Exception as e:
            self._emit_not_running(str(e))

    def _emit_snapshot(self, micro, rest, daily):
        if not self.is_connected or not self.core_iface:
            self._emit_not_running()
            return
        try:
            mode = str(self.core_iface.GetOperationMode())
            micro_running = bool(self.core_iface.IsTimerRunning("microbreak"))
            idle_sec = int(self.core_iface.GetTimerIdle("microbreak"))
            micro_state = str(self.core_iface.GetBreakState("microbreak"))
            rest_state = str(self.core_iface.GetBreakState("restbreak"))

            micro_rem = int(micro[7]) - int(micro[6]) if int(micro[7]) > 0 else 0
            rest_rem = int(rest[7]) - int(rest[6]) if int(rest[7]) > 0 else 0
            daily_rem = int(daily[7]) - int(daily[6]) if int(daily[7]) > 0 else 0

            payload = {
                "running": True,
                "mode": mode,
                "user_active": micro_running,
                "idle_seconds": idle_sec,
                "micro": {
                    "text": str(micro[0]),
                    "remaining": max(0, micro_rem),
                    "limit": int(micro[7]),
                    "elapsed": int(micro[6]),
                    "state": micro_state
                },
                "rest": {
                    "text": str(rest[0]),
                    "remaining": max(0, rest_rem),
                    "limit": int(rest[7]),
                    "elapsed": int(rest[6]),
                    "state": rest_state
                },
                "daily": {
                    "text": str(daily[0]),
                    "remaining": max(0, daily_rem),
                    "limit": int(daily[7]),
                    "elapsed": int(daily[6]),
                    "state": "none"
                }
            }
            print(json.dumps(payload), flush=True)
        except Exception as e:
            self._emit_not_running(str(e))

    @staticmethod
    def _format_seconds(seconds: int) -> str:
        if seconds < 0:
            return "0:00"
        m, s = divmod(seconds, 60)
        h, m = divmod(m, 60)
        if h > 0:
            return f"{h}:{m:02d}:{s:02d}"
        return f"{m}:{s:02d}"

    def run(self):
        # Initial check
        try:
            self.bus.get_name_owner(BUS_NAME)
            self._connect()
        except dbus.DBusException:
            self._emit_not_running()
        self.loop.run()


def main():
    if len(sys.argv) > 1:
        if sys.argv[1] == "action" and len(sys.argv) > 2:
            execute_action(sys.argv[2])
            return
        elif sys.argv[1] == "--help" or sys.argv[1] == "-h":
            print("Usage: workrave-monitor.py [action <action_name>]")
            return

    monitor = WorkraveMonitor()
    try:
        monitor.run()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
