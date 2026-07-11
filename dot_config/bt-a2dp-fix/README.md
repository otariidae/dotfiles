# Bluetooth A2DP recovery

This workaround targets Bluetooth devices that occasionally reconnect in the
wrong `audio-gateway` direction instead of an A2DP playback profile.

The observed device advertises both A2DP Source and Sink services. On affected
connections, the Source direction occupies the shared AVDTP session and a Sink
connection fails with `Device or resource busy`.

## Architecture

1. WirePlumber enables A2DP Sink auto-connect and prefers the configured
   playback profiles for this device.
2. `bt-a2dp-monitor.service` listens for the device's BlueZ
   `Device1.Connected=true` D-Bus signal.
3. After a short grace period, the monitor ignores healthy A2DP connections and
   starts `bt-a2dp-fix.service` for missing or non-A2DP profiles.
4. The recovery service:
   - exits immediately when the target or fallback profile is active;
   - selects an already available playback profile;
   - disconnects the conflicting A2DP Source service and connects A2DP Sink;
   - performs at most one full device reconnect as a fallback.

The recovery service is idempotent and bounded by a systemd timeout.

## Setup

Edit `config`, then run:

```bash
bin/setup-bt-a2dp-fix
```

The setup script validates dependencies and the WirePlumber version, generates
device-specific WirePlumber 0.4 configuration, links the managed files, reloads
WirePlumber, and enables the monitor.

This configuration is intentionally limited to WirePlumber 0.4.x. WirePlumber
0.5 uses a different configuration format and requires a migration.

## Diagnostics

```bash
journalctl -t bt-a2dp-fix -b
systemctl --user status bt-a2dp-monitor.service bt-a2dp-fix.service
bluetoothctl info <MAC>
pactl list cards
```

A successful targeted recovery contains:

```text
trigger reason=connected profile=audio-gateway
replacing A2DP source with sink profile
ok profile=a2dp-sink-sbc_xq
```

If targeted recovery fails, the log contains:

```text
A2DP sink unavailable; reconnecting device
```

## Tests

```bash
tests/bt-a2dp-fix-test.sh
```

The tests cover healthy connections, targeted Source-to-Sink recovery, the
single reconnect fallback, bounded failure, and duplicate event suppression.

## Removal criteria

Retest without the workaround after upgrading BlueZ, PipeWire, WirePlumber, or
the device firmware. Remove it when repeated cold connections, reconnects, and
suspend/resume cycles consistently select A2DP without recovery.
