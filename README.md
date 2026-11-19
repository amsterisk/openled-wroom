# OpenLED WROOM host board

An open-hardware LED controller board for an ESP32-WROOM-32E module running
[WLED](https://kno.wled.ge). It has 5 V in and four level-shifted WS2812B data outputs.

Status: **work in progress**. The schematic is done (ERC clean) and the PCB is routed (DRC clean).
It has not yet been reviewed or fabricated.

## Features

- **ESP32-WROOM-32E** module. The antenna overhangs the top edge of the board, so there is no copper under it.
- **Four WS2812B outputs** on GPIO16, 17, 18 and 19:
  - Buffered to 5 V by a **74AHCT125**. Its TTL-threshold inputs are driven from 3.3 V.
  - A 220 Ω series resistor on each output.
  - A 10 kΩ pull-down on each output, so the strips stay dark while the ESP32 boots.
- **Capacity:** four outputs drive about 1440 LEDs at around 80 fps, for example 24 m of 60 LED/m
  strip split across them. A single 1440-LED output would only reach about 23 fps.
- **5 V input for logic only** (about 0.3 A peak):
  - Reverse-polarity protection (AO3401A P-FET).
  - SMBJ5.0A TVS.
  - AMS1117-3.3 regulator.
- **Button on GPIO0**. This is WLED's default button: tap for on/off, long-press to reset to AP mode.
  Holding it during reset enters download mode.
- **No USB or UART.** The module is flashed before assembly. After that, update over Wi-Fi (WLED OTA).
- 2-layer board, 54 × 39 mm, with two M3 mounting holes.

## Connectors

All connectors are 2-pin JST XH (2.5 mm pitch, vertical, B2B-XH-A). Pin 1 is the signal and pin 2 is GND.

| Ref | Pin 1 | Pin 2 |
|---|---|---|
| J1 | +5 V in | GND |
| J2–J5 | LED data D1–D4 | GND |

Each output has its own connector, so you only need to fit the outputs you use. Fit at least J2
(D1), and set WLED to match.

Each output's GND pin is the data ground reference. **LED power does not go through this board.**
Wire the strip power straight from the PSU(s):
- Inject power about every 150–200 LEDs, with heavy wire and a fuse on each run.
- Join each strip's GND to its output's GND pin.
- Keep the data run from the board to the first LED short (under a few metres).

The data ground wires run in parallel with the heavy power returns. Keep the board near where the
strips are fed, so only a small share of the LED current flows back through it. XH pins are rated
about 3 A.

At full white, 1440 LEDs can draw about 86 A. Set WLED's brightness limiter to about 80 % of what
your supplies can deliver.

## WLED settings

- **LED Preferences:** four outputs, type WS281x, data GPIO **16, 17, 18, 19** (D1–D4).
- **Button 0:** GPIO0, type Pushbutton.
- **Brightness limiter:** on, sized to your PSU(s).

## Building fabrication files

```sh
tools/export.sh            # version from `git describe`; refuses to build if ERC/DRC fail
tools/export.sh v1.0       # explicit version
tools/export.sh --allow-violations   # work-in-progress builds
```

Outputs land in `production/<version>/`. That folder is git-ignored; attach its contents to a
GitHub release. It contains:
- A Gerber + drill zip. Upload it as-is to JLCPCB or PCBWay.
- A grouped BOM, plus a JLCPCB-format BOM and placement file.
- The schematic PDF and top/bottom 3D renders.
- The ERC/DRC reports.

You need KiCad 9 (`kicad-cli`).

Design rules target JLCPCB's standard 2-layer process. They are set in Board Setup → Constraints
plus `hardware/openled-wroom.kicad_dru`:
- 0.15 mm minimum track width and clearance.
- **All vias 0.6/0.3 mm or larger**, so the board needs no small-via surcharge.
- 0.3 mm copper-to-edge.

Net classes:
- *Default:* 0.25 mm tracks.
- *Power:* 0.5 mm tracks and 0.8/0.4 mm vias, for +5V, +3V3, GND and VIN.

## Repository layout

- `hardware/`: the KiCad 9 project (`openled-wroom.kicad_pro`).
  - `openled.pretty/ESP32-WROOM-32E` is KiCad's stock footprint with two changes: its
    exposed-pad thermal vias are opened from 0.2 to 0.3 mm, and the pin-1 marker is moved onto the board.
  - `openled.pretty/amsterisk-logo` is the silkscreen logo.
- `tools/export.sh`: builds the fabrication and documentation outputs.
- `LICENSE`: CERN-OHL-S-2.0.

## Licence

Copyright the contributors. Licensed under the **CERN Open Hardware Licence Version 2 –
Strongly Reciprocal** (CERN-OHL-S-2.0). See `LICENSE`.
