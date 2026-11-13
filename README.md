# K4 Display — proof of root command execution 
 
## Concept


This tool demonstrates that the printer's own file upload interface — the
same one used for sending print jobs — can be used for device customization.
No disassembly. No firmware flashing. No permanent modifications. The video
plays, you touch the screen, and your printer is exactly as it was before.

It's a proof of concept for **device ownership**: if you buy hardware, you
should be able to use every part of it — including the display.

## What It Does

1. **Video playback:** Plays a short video on your printer's display as an
   endless loop. Touch the screen and your normal UI comes back.

2. **Firmware self-check (--inspect):** Shows what actually runs on your
   device — build stamps, Klipper components, GPL compliance indicators.
   Useful for verifying that GPL-licensed software on your printer is
   properly documented and attributed.

## The Security Issues

This tool works because the Kobra 4 firmware (version 1.2.1.3) has several
security issues in its LAN-accessible web interface. These are documented
here for **responsible disclosure** purposes.

### Issue 1: Unauthenticated API Access (HTTP :18910)

The printer's HTTP interface requires no authentication:

```
GET /info   -> public device token (no login required)
POST /ctrl  -> returns MQTT credentials (signature is computed from the
              public token — effectively no secret required)
```

**Impact:** Anyone on the same network can extract MQTT credentials and
upload tokens without any password or key.

### Issue 2: Offline-Forgeable Signature

The `/ctrl` endpoint verifies requests with `MD5(MD5(token[:16]) + ts + nonce)`.
Both the token and the algorithm are public. The signature can be computed
offline without any secret.

**Impact:** The API signature provides zero security — it's a speed bump,
not a lock.

### Issue 3: Filename Injection in Upload Handler (Critical)

The file upload endpoint (`POST /gcode_upload`) passes the uploaded
filename to a shell command (`system()`) without sanitization:

```
Uploaded filename:  x'; touch /tmp/PWNED; #.gcode.3mf
Shell executes:     unzip ... x'; touch /tmp/PWNED; #.gcode.3mf ...
                    -> runs "touch /tmp/PWNED" as root
```

**Impact:** Arbitrary command execution as root on the printer, from the
network, without authentication. This is the mechanism this tool uses to
start the video playback.

### Issue 4: No Upload Content Validation

The upload handler accepts arbitrary binary content as "gcode" — it only
validates the 3MF container structure, not the gcode content itself.
Video frames, binaries, and scripts pass through unchanged.

**Impact:** Any binary payload can be stored on the printer's filesystem.

## How the Tool Uses These Issues

```
Step 1: GET /info          -> obtain public token
Step 2: POST /ctrl         -> extract MQTT credentials (forge signature)
Step 3: MQTT query         -> obtain upload token
Step 4: Upload N frames    -> each frame as a valid 3MF container
Step 5: Upload injection   -> filename triggers shell command as root
Step 6: Video plays        -> loop writes frames to /dev/fb0
Step 7: Touch screen       -> video stops, UI restarts
```

Total time from start to video playing: **~10 seconds** for 21 frames.

## Quick Start

```bash
pip install -r requirements.txt
python3 k4_display.py <printer-ip>
```

Emulator (local testing):
```bash
K4_HTTP_PORT=18912 K4_MQTT_PORT=9885 python3 k4_display.py 127.0.0.1
```

## Firmware Self-Check

```bash
python3 k4_display.py <ip> --inspect
```

Checks for build stamps (`commit=...`), Klipper strings, and
`identify_data` presence in the firmware binary. Results appear in the
terminal and on the printer's file list.

## Using Your Own Video

```bash
./make_slides.sh my_video.mp4
python3 k4_display.py <ip>
```

## What's NOT Affected by this script

- No firmware is modified
- No permanent changes to the printer
- Touch the screen -> normal UI returns
- Reboot -> everything back to factory state
- The printer continues printing normally after the demo

## Compatibility

Works on stock (vanilla) firmware 1.2.1.3. The code avoids `seq`, `pidof`,
`awk`, `xargs` and other BusyBox applets that are compiled into the
firmware but not symlinked in `/bin` — only universally available tools
are used.

## Content Format

Video frames are stored as Base64-encoded text files (`.b64`) with MD5
checksums — no binary files in this repository. Each frame is 480x320
pixels at 32 bpp (XRGB8888), exactly 614,400 bytes, compressed with xz.

## Legal

**For your own printer only.** This uses documented security issues for
device customization and GPL compliance verification. If you are a
security researcher, this serves as a proof of concept for responsible
disclosure to the manufacturer.

**License:** GPL v3 — because your printer's firmware and he running dtolen klipper is GPL too.
