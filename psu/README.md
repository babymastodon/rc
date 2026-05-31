# MSI Ai1600T PSU Watch

`msi-psu-watch` reads MSI MEG Ai1600T PCIe5 PSU telemetry on Linux through the
PSU's USB HID interface. It prints the current +12V, +5V, +3.3V, output power,
efficiency, temperature, fan speed, and runtime.

The tool uses only the Python standard library. It does not require MSI Center,
OpenHardwareMonitor, or any Python packages.

## Supported Device

This was tested with:

```text
0db0:c9eb Micro-Star International MSI MEG Ai1600T
```

The PSU exposes a vendor HID device with 64-byte input and output reports. It
does not currently expose a native Linux `hwmon` device, so tools like `btop`
will not discover it automatically.

## Install

Connect the PSU USB cable, then run the installer:

```sh
./install_msi_psu_watch.sh
```

The installer checks that the Ai1600T USB device is visible before it installs
anything. If the device is found, it symlinks `msi-psu-watch` into
`~/.local/bin`.

To use a different bin directory:

```sh
sudo env BIN_DIR=/usr/local/bin ./install_msi_psu_watch.sh
```

If `msi-psu-watch` cannot open `/dev/msi-ai1600t`, add a udev rule so your
desktop user can access the PSU HID device without running the monitor as root:

```sh
sudo tee /etc/udev/rules.d/70-msi-ai1600t.rules >/dev/null <<'EOF'
SUBSYSTEM=="hidraw", ATTRS{idVendor}=="0db0", ATTRS{idProduct}=="c9eb", TAG+="uaccess", SYMLINK+="msi-ai1600t"
EOF

sudo udevadm control --reload-rules
sudo udevadm trigger
```

Unplug and reconnect the PSU USB cable if `/dev/msi-ai1600t` does not appear.
Then verify the device path with:

```sh
ls -l /dev/msi-ai1600t
```

## Use

Run the live terminal view:

```sh
msi-psu-watch
```

Print one sample and exit:

```sh
msi-psu-watch --once
```

Print newline-delimited JSON for another tool to consume:

```sh
msi-psu-watch --json
```

Use a different hidraw path:

```sh
msi-psu-watch --device /dev/hidrawN
```

## Notes

The script sends only the read commands validated for this PSU:

```text
00 fa 51  product name
00 51 e0  live telemetry
00 51 d1  runtime
```

The PSU replies with a two-byte command echo followed by PMBus Linear11 telemetry
values. Runtime is returned as an integer divided by 100 and is displayed as
hours.
