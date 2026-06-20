# Hardware Sensors

`hwstat` is the single watch command for motherboard `hwmon` telemetry, MSI
MEG Ai1600T PSU telemetry, and optional NVIDIA GPU telemetry. Display policy
lives in TOML config: labels, ordering, hidden sensors, grouping, and whether
the PSU and GPU are shown.

## Files

- `hwstat`: combined Linux `hwmon`, MSI PSU, and NVIDIA GPU monitor.
- `sensors.toml`: active default config used when running the script from this
  repo or through the installer symlink.
- `sensors.toml.example`: template for another machine or user config.
- `install_sensors.sh`: installs the watch command into `~/.local/bin` and
  removes stale `mobo-watch` and `msi-psu-watch` symlinks from older installs.
- `install_msi_ai1600t_udev.sh`: installs the optional MSI PSU hidraw udev rule.

## Install

```sh
./install_sensors.sh
```

The installer symlinks `hwstat` into `~/.local/bin`, cleans up old
`mobo-watch` and `msi-psu-watch` links it previously managed, and prints a
sensor diagnostic report.

## Use

Watch the configured motherboard and PSU sections:

```sh
hwstat
```

Useful variants:

```sh
hwstat --once
hwstat --json
hwstat --all
hwstat --no-psu
hwstat --gpu
hwstat --no-gpu
hwstat --check
```

`--all` temporarily includes hwmon devices not listed in the config. `--no-psu`
temporarily disables PSU reads even when config enables them. `--gpu` and
`--no-gpu` override the configured NVIDIA GPU reader.

## Configure Display

By default, the script uses the first existing config:

1. `~/.config/hwstat/config.toml`
2. legacy `~/.config/mobo-watch/config.toml`
3. `sensors.toml` next to `hwstat`

Edit `sensors.toml` in this directory for this repo-managed machine, or copy the
template to user config:

```sh
mkdir -p ~/.config/hwstat
cp sensors.toml.example ~/.config/hwstat/config.toml
```

You can also pass a config explicitly:

```sh
hwstat --config ./sensors.toml
```

Device rules match by `match`, `name`, `hwmon`, or `path`. Sensor and PSU metric
rules match by `key` or `match`. The most useful keys are raw kernel names such
as `temp1`, `fan3`, or PSU metric keys like `output_power` and computed
`input_power`.

The local config sets:

```toml
[display]
show_unconfigured = false

[psu]
enabled = true

[gpu]
enabled = true
```

That keeps the default view focused on configured board, PSU, and GPU sections.
Use `hwstat --all` while discovering sensors on new hardware.

NVIDIA GPU telemetry shells out to `nvidia-smi` through Python's standard
library. GPU temperatures are shown in `Temps`; GPU power draw is shown in
`Power`.

## ASUS Pro WS WRX90E-SAGE SE Sensor Mapping

Board telemetry on this board needs no out-of-tree driver. Two in-tree drivers
provide everything, and both expose their own labels, so `sensors.toml` only
sets grouping/ordering and lets the driver labels stand:

- `k10temp` exposes the CPU package temperature as `Tctl`.
- `asusec` (the ASUS embedded-controller driver) exposes four temperatures —
  `CPU Package`, `T_Sensor`, `VRM_E`, `VRM_W` — and five fan channels —
  `CPU_Opt`, `VRME HS`, `VRMW HS`, `USB4`, `M.2`.

`asusec` only surfaces the EC-monitored headers, not every physical fan header
on the board. The `VRME HS` / `VRMW HS` channels read `0` when no fan is wired
to the VRM heatsink headers. Use `hwstat --all` to discover any additional
hwmon devices a future kernel exposes.

### Nuvoton NCT6798D Super-I/O (extra fans + system temp)

The board also carries a Nuvoton NCT6798D Super-I/O chip that the `asusec`
driver intentionally skips. It exposes the `System` (SYSTIN) temperature and the
CPU/chassis fan headers that the EC does not report. Load the in-tree driver:

```sh
sudo modprobe nct6775          # try once now
echo nct6775 | sudo tee /etc/modules-load.d/nct6775.conf   # load on every boot
```

On this kernel the driver binds without `acpi_enforce_resources=lax`; if a
future kernel logs an ACPI resource conflict and refuses to bind, add
`acpi_enforce_resources=lax` to the kernel command line.

The NCT6798D's channel labels are generic (`SYSTIN`, `CPUTIN`, `AUXTIN*`,
`fan1`..`fan7`) and several channels are unconnected on this AMD platform, so
`sensors.toml` hides the CPU-duplicate temps, the always-zero `PCH_*`
registers, and the unconnected `AUXTIN` probes. The fan channels map to physical
headers in no documented order — identify each one by changing a single header's
curve in BIOS Q-Fan (or unplugging it) and watching which `fanN` value moves,
then relabel it in `sensors.toml`.

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

PSU HID access is serialized because concurrent command sequences can corrupt
replies. `hwstat` caches the last successful raw PSU read in
`/tmp/hwstat-msi-psu.json` for one second, and readers that arrive while another
process is refreshing the device can reuse that cache for up to five seconds.
