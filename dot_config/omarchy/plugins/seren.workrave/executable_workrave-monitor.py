#!/usr/bin/env python3
"""
Workrave D-Bus monitor and action helper for Omarchy shell plugin.
Streams state changes as JSON lines to stdout and handles control actions.
Includes timed auto-reset tracking and anti-forgetting work watchdogs.
"""

import sys
import json
import time
import subprocess
import dbus
import dbus.mainloop.glib
from gi.repository import GLib, Gio

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
            if mode in ("suspended", "quiet"):
                try:
                    core.SkipBreak("microbreak")
                except Exception:
                    pass
                try:
                    core.SkipBreak("restbreak")
                except Exception:
                    pass
            print(f"Set mode to {mode}")
        elif action.startswith("usage_"):
            usage = action[len("usage_"):]
            core_obj = bus.get_object(BUS_NAME, CORE_PATH)
            core = dbus.Interface(core_obj, CORE_IFACE)
            core.SetUsageMode(usage)
            print(f"Set usage mode to {usage}")
        elif action == "toggle_reading":
            core_obj = bus.get_object(BUS_NAME, CORE_PATH)
            core = dbus.Interface(core_obj, CORE_IFACE)
            cur = str(core.GetUsageMode())
            new_mode = "reading" if cur != "reading" else "normal"
            core.SetUsageMode(new_mode)
            print(f"Toggled usage mode to {new_mode}")
        elif action.startswith("timed_"):
            # timed_suspended_30, timed_quiet_60, timed_suspended_0, etc.
            parts = action.split("_")
            if len(parts) >= 3:
                mode_type = parts[1]
                duration = parts[2]
                ui_obj = bus.get_object(BUS_NAME, UI_PATH)
                ui = dbus.Interface(ui_obj, UI_IFACE)
                menu_action = f"workrave.mode_timed_{mode_type}.{duration}"
                ui.MenuAction(menu_action)
                print(f"Executed {menu_action}")
        elif action == "extend_timed":
            # Add 15 minutes to current timed mode
            settings = Gio.Settings.new("org.workrave.general")
            current_time = settings.get_int64("operation-mode-auto-reset-time")
            if current_time > 0:
                new_time = max(int(time.time()), current_time) + 900
                settings.set_int64("operation-mode-auto-reset-time", new_time)
                print(f"Extended auto-reset time to {new_time}")
        elif action == "activity":
            core_obj = bus.get_object(BUS_NAME, CORE_PATH)
            core = dbus.Interface(core_obj, CORE_IFACE)
            core.ReportActivity("mouse", True)
            print("Reported activity")
        elif action in ("open", "preferences", "restbreak", "exercises", "statistics", "about", "quit"):
            ui_obj = bus.get_object(BUS_NAME, UI_PATH)
            ui = dbus.Interface(ui_obj, UI_IFACE)
            menu_action = f"workrave.{action}"
            ui.MenuAction(menu_action)
            print(f"Executed {menu_action}")
        elif action in ("skip_current", "skip_microbreak", "skip_restbreak"):
            core_obj = bus.get_object(BUS_NAME, CORE_PATH)
            core = dbus.Interface(core_obj, CORE_IFACE)
            if action == "skip_microbreak":
                core.SkipBreak("microbreak")
                print("Skipped microbreak")
            elif action == "skip_restbreak":
                core.SkipBreak("restbreak")
                print("Skipped restbreak")
            else:
                m_state = str(core.GetBreakState("microbreak"))
                r_state = str(core.GetBreakState("restbreak"))
                if m_state not in ("", "none"):
                    core.SkipBreak("microbreak")
                    print("Skipped microbreak")
                elif r_state not in ("", "none"):
                    core.SkipBreak("restbreak")
                    print("Skipped restbreak")
                else:
                    try:
                        core.SkipBreak("microbreak")
                    except Exception:
                        pass
                    try:
                        core.SkipBreak("restbreak")
                    except Exception:
                        pass
                    print("Skipped active breaks")
        elif action in ("postpone_current", "postpone_microbreak", "postpone_restbreak"):
            core_obj = bus.get_object(BUS_NAME, CORE_PATH)
            core = dbus.Interface(core_obj, CORE_IFACE)
            if action == "postpone_microbreak":
                core.PostponeBreak("microbreak")
                print("Postponed microbreak")
            elif action == "postpone_restbreak":
                core.PostponeBreak("restbreak")
                print("Postponed restbreak")
            else:
                m_state = str(core.GetBreakState("microbreak"))
                r_state = str(core.GetBreakState("restbreak"))
                if m_state not in ("", "none"):
                    core.PostponeBreak("microbreak")
                    print("Postponed microbreak")
                elif r_state not in ("", "none"):
                    core.PostponeBreak("restbreak")
                    print("Postponed restbreak")
                else:
                    try:
                        core.PostponeBreak("microbreak")
                    except Exception:
                        pass
                    try:
                        core.PostponeBreak("restbreak")
                    except Exception:
                        pass
                    print("Postponed active breaks")
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
        self.usage_receiver = None
        self.break_skipped_receiver = None
        self.break_postponed_receiver = None
        self.last_micro = None
        self.last_rest = None
        self.last_daily = None

        # GSettings for auto-reset timing
        try:
            self.settings = Gio.Settings.new("org.workrave.general")
        except Exception:
            self.settings = None

        # Watchdog state
        self.active_work_seconds_while_suspended = 0
        self.last_work_reminder_time = 0
        self.reading_mode_start_time = None
        self.last_reading_reminder_time = 0

        self.bus.watch_name_owner(BUS_NAME, self._on_name_owner_changed)
        try:
            GLib.io_add_watch(sys.stdin.fileno(), GLib.IO_IN, self._on_stdin_readable)
        except Exception:
            pass

        # Periodic timer for watchdog and countdown updates (1 second)
        GLib.timeout_add_seconds(1, self._on_second_tick)

    def _on_stdin_readable(self, source, condition):
        try:
            line = sys.stdin.readline()
            if not line:
                return False
            cmd = line.strip()
            if cmd in ("activity", "ping"):
                if self.core_iface:
                    mode = str(self.core_iface.GetOperationMode())
                    if mode == "normal":
                        micro_state = str(self.core_iface.GetBreakState("microbreak"))
                        rest_state = str(self.core_iface.GetBreakState("restbreak"))
                        try:
                            micro_rem = int(self.core_iface.GetTimerRemaining("microbreak"))
                        except Exception:
                            micro_rem = 100
                        try:
                            rest_rem = int(self.core_iface.GetTimerRemaining("restbreak"))
                        except Exception:
                            rest_rem = 100
                        if (micro_state in ("", "none") and
                            rest_state in ("", "none") and
                            micro_rem > 2 and
                            rest_rem > 2):
                            self.core_iface.ReportActivity("dbus", True)
                        # Reset suspended work accumulator
                        self.active_work_seconds_while_suspended = 0
                    elif mode in ("suspended", "quiet"):
                        # User is actively working while in suspended or quiet mode
                        self.active_work_seconds_while_suspended += 2
                        now = time.time()

                        # 20 minutes of continuous typing while suspended -> gentle reminder
                        if self.active_work_seconds_while_suspended >= 1200 and now - self.last_work_reminder_time > 300:
                            self.last_work_reminder_time = now
                            mins = self.active_work_seconds_while_suspended // 60
                            self._send_notification(
                                "Workrave is Suspended",
                                f"Active typing detected for {mins} minutes. Breaks remain paused.",
                                urgency="normal"
                            )

                        # 30 minutes of continuous typing while suspended -> auto resume normal mode
                        if self.active_work_seconds_while_suspended >= 1800:
                            self.active_work_seconds_while_suspended = 0
                            try:
                                self.core_iface.SetOperationMode("normal")
                                self._send_notification(
                                    "Workrave Auto-Resumed",
                                    "Continuous work detected for 30 minutes while suspended. Normal break monitoring restored.",
                                    urgency="critical"
                                )
                            except Exception:
                                pass
        except Exception:
            pass
        return True

    def _send_notification(self, title: str, body: str, urgency: str = "normal"):
        try:
            subprocess.Popen([
                "notify-send",
                "-a", "Workrave",
                "-i", "workrave",
                "-u", urgency,
                title, body
            ])
        except Exception:
            pass

    def _on_second_tick(self):
        # Decay active work accumulator slowly if user stopped typing
        if self.active_work_seconds_while_suspended > 0:
            self.active_work_seconds_while_suspended = max(0, self.active_work_seconds_while_suspended - 1)

        # Check Reading Mode duration
        if self.is_connected and self.core_iface:
            try:
                usage = str(self.core_iface.GetUsageMode())
                now = time.time()
                if usage == "reading":
                    if self.reading_mode_start_time is None:
                        self.reading_mode_start_time = now
                    elif now - self.reading_mode_start_time >= 2700 and now - self.last_reading_reminder_time > 900:
                        # 45 minutes of reading mode
                        self.last_reading_reminder_time = now
                        self._send_notification(
                            "Reading Mode Reminder",
                            "Reading mode active for 45 minutes without keyboard input. Break timers will prompt soon.",
                            urgency="normal"
                        )
                else:
                    self.reading_mode_start_time = None
            except Exception:
                pass

        # If a timed mode is active, emit periodic update so countdown increments smoothly
        reset_rem = self._get_reset_remaining()
        if reset_rem > 0 and self.last_micro and self.last_rest and self.last_daily:
            self._emit_snapshot(self.last_micro, self.last_rest, self.last_daily)

        return True

    def _get_reset_info(self):
        if not self.settings:
            return 0, 0
        try:
            reset_time = self.settings.get_int64("operation-mode-auto-reset-time")
            reset_dur = self.settings.get_int("operation-mode-auto-reset-duration")
            now = int(time.time())
            rem = max(0, reset_time - now) if reset_time > 0 else 0
            return rem, reset_dur
        except Exception:
            return 0, 0

    def _get_reset_remaining(self) -> int:
        rem, _ = self._get_reset_info()
        return rem

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
            if not self.usage_receiver:
                self.usage_receiver = self.bus.add_signal_receiver(
                    self._on_usage_changed,
                    signal_name="UsageModeChanged",
                    dbus_interface=CORE_IFACE
                )
            if not self.break_skipped_receiver:
                self.break_skipped_receiver = self.bus.add_signal_receiver(
                    self._on_break_event,
                    signal_name="BreakSkipped",
                    dbus_interface=CORE_IFACE
                )
            if not self.break_postponed_receiver:
                self.break_postponed_receiver = self.bus.add_signal_receiver(
                    self._on_break_event,
                    signal_name="BreakPostponed",
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
        self.active_work_seconds_while_suspended = 0
        self._emit_current_state()

    def _on_usage_changed(self, mode):
        self._emit_current_state()

    def _on_break_event(self, timer_id):
        self._emit_current_state()

    def _on_timers_updated(self, micro, rest, daily):
        self.last_micro = micro
        self.last_rest = rest
        self.last_daily = daily
        self._emit_snapshot(micro, rest, daily)

    def _get_usage_mode(self) -> str:
        try:
            return str(self.core_iface.GetUsageMode())
        except Exception:
            return "normal"

    def _emit_current_state(self):
        if not self.is_connected or not self.core_iface:
            self._emit_not_running()
            return
        try:
            mode = str(self.core_iface.GetOperationMode())
            usage_mode = self._get_usage_mode()
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

            reset_rem, reset_dur = self._get_reset_info()

            payload = {
                "running": True,
                "mode": mode,
                "usage_mode": usage_mode,
                "user_active": micro_running,
                "idle_seconds": idle_sec,
                "reset_remaining": reset_rem,
                "reset_duration": reset_dur,
                "active_work_suspended": self.active_work_seconds_while_suspended,
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
            usage_mode = self._get_usage_mode()
            micro_running = bool(self.core_iface.IsTimerRunning("microbreak"))
            idle_sec = int(self.core_iface.GetTimerIdle("microbreak"))
            micro_state = str(self.core_iface.GetBreakState("microbreak"))
            rest_state = str(self.core_iface.GetBreakState("restbreak"))

            micro_rem = int(micro[7]) - int(micro[6]) if int(micro[7]) > 0 else 0
            rest_rem = int(rest[7]) - int(rest[6]) if int(rest[7]) > 0 else 0
            daily_rem = int(daily[7]) - int(daily[6]) if int(daily[7]) > 0 else 0

            reset_rem, reset_dur = self._get_reset_info()

            payload = {
                "running": True,
                "mode": mode,
                "usage_mode": usage_mode,
                "user_active": micro_running,
                "idle_seconds": idle_sec,
                "reset_remaining": reset_rem,
                "reset_duration": reset_dur,
                "active_work_suspended": self.active_work_seconds_while_suspended,
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
        elif sys.argv[1] in ("--help", "-h"):
            print("Usage: workrave-monitor.py [action <action_name>]")
            return

    monitor = WorkraveMonitor()
    try:
        monitor.run()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
