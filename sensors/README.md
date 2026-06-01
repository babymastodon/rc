# Hardware Sensors

`mobo-watch` is the single watch command for motherboard `hwmon` telemetry and
MSI MEG Ai1600T PSU telemetry. Display policy lives in TOML config: labels,
ordering, hidden sensors, grouping, and whether the PSU is shown.

## Files

- `mobo-watch`: combined Linux `hwmon` and MSI PSU monitor.
- `sensors.toml`: active default config used when running the script from this
  repo or through the installer symlink.
- `sensors.toml.example`: template for another machine or user config.
- `install_sensors.sh`: installs the watch command into `~/.local/bin` and
  removes stale `msi-psu-watch` symlinks from older installs.
- `install_msi_ai1600t_udev.sh`: installs the optional MSI PSU hidraw udev rule.
- `install_gigabyte_trx50_it87_dkms.sh`: board-specific DKMS helper for the
  Gigabyte TRX50 AI TOP iTE sensor path.

## Install

```sh
./install_sensors.sh
```

The installer symlinks `mobo-watch` into `~/.local/bin`, cleans up old
`msi-psu-watch` links it previously managed, and prints a sensor diagnostic
report.

## Use

Watch the configured motherboard and PSU sections:

```sh
mobo-watch
```

Useful variants:

```sh
mobo-watch --once
mobo-watch --json
mobo-watch --all
mobo-watch --no-psu
mobo-watch --check
```

`--all` temporarily includes hwmon devices not listed in the config. `--no-psu`
temporarily disables PSU reads even when config enables them.

## Configure Display

By default, the script uses the first existing config:

1. `~/.config/mobo-watch/config.toml`
2. `sensors.toml` next to `mobo-watch`

Edit `sensors.toml` in this directory for this repo-managed machine, or copy the
template to user config:

```sh
mkdir -p ~/.config/mobo-watch
cp sensors.toml.example ~/.config/mobo-watch/config.toml
```

You can also pass a config explicitly:

```sh
mobo-watch --config ./sensors.toml
```

Device rules match by `match`, `name`, `hwmon`, or `path`. Sensor and PSU metric
rules match by `key` or `match`. The most useful keys are raw kernel names such
as `temp1`, `fan3`, or PSU metric keys like `output_power`.

The local config sets:

```toml
[display]
show_unconfigured = false

[psu]
enabled = true
```

That keeps the default view focused on configured board and PSU sections. Use
`mobo-watch --all` while discovering sensors on new hardware.

## TRX50 AI TOP Sensor Mapping

The current TRX50 AI TOP labels are best-effort but evidence-based:

- The motherboard exposes two ITE controllers: `it8689` at `0x0a40` and
  `it87952` at `0x0a60`.
- The manual lists eight fan-capable headers: `CPU_FAN`, `SYS_FAN1/2`,
  `SYS_FAN5/6/7/8_PUMP`, and `CPU_OPT`.
- Linux exposes eight fan channels across those two controllers.
- `it8689 temp3` reports `temp3_type=5`, which lm-sensors identifies as AMD
  AMDSI, so it is labeled `CPU`.
- The main temperature order follows the Gigabyte mappings used by the
  maintained `it87` sensor configs for recent boards:
  `System 1`, `PCH`, `CPU`, `PCIEX16`, `VRM MOS`, `EC_TEMP1`.
- `it87952 temp2` is labeled `EC_TEMP2`.

The fan header order is inferred as:

```text
it8689 fan1  CPU_FAN
it8689 fan2  SYS_FAN1
it8689 fan3  SYS_FAN2
it8689 fan4  SYS_FAN5_PUMP
it8689 fan5  CPU_OPT
it87952 fan1 SYS_FAN6_PUMP
it87952 fan2 SYS_FAN7_PUMP
it87952 fan3 SYS_FAN8_PUMP
```

The only way to prove fan header mapping fully is to identify headers one at a
time in BIOS Smart Fan 6 or by temporarily changing one header's speed curve and
watching which Linux RPM changes.

### Secondary Controller Notes

The `it87952` controller exposes three temperature registers through `it87`.
If `EC_TEMP2` ever reports `-55 C`, treat it as a bad raw reading from Linux
rather than a valid board temperature.

This board also exposes `048d:5711 ITE Tech. Inc. GIGABYTE Device` as two USB
HID interfaces. One interface has sensor-like feature reports, and the kernel
`gigabyte-wmi` driver probes the board WMI GUID but logs `No temperature
sensors usable`.

## Optional MSI PSU Setup

The PSU reader uses `/dev/msi-ai1600t` by default and can fall back to the
matching `hidraw` node when the device is visible. For regular non-root access,
install the udev rule:

```sh
./install_msi_ai1600t_udev.sh
```

The reader was tested with this USB device:

```text
0db0:c9eb Micro-Star International MSI MEG Ai1600T
```

## Gigabyte TRX50 AI TOP

This board uses a Gigabyte/iTE monitoring path. On the tested Linux install,
the in-tree `it87` module exposed only the secondary controller. The full sensor
set required the maintained out-of-tree driver from `frankcrawford/it87`.

To install that driver with DKMS:

```sh
./install_gigabyte_trx50_it87_dkms.sh
```

The helper builds commit `20f2f2f`, applies the local TRX50 AI TOP DMI patch,
registers the patched module with DKMS, reloads it, and verifies with
`mobo-watch --check`.

The DMI patch marks the board's ACPI resource conflict as expected for this
specific motherboard. That replaces the broader `options it87
ignore_resource_conflict=1` workaround used by the first local installer.
