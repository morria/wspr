# WSPR

A small, native iOS app for sending and receiving **WSPR** (Weak Signal Propagation
Reporter) data. Transmit WSPR beacons through your device's audio into a VOX-keyed
radio, and browse reception reports on a map or list with rich filtering.

Built with SwiftUI (iOS 17+), MapKit, AVFoundation and CoreLocation. No third-party
dependencies.

---

## What it does

**Transmit**
- Toggle transmit on and the app runs the standard WSPR cycle continuously: it waits
  for the next even-minute UTC slot, then plays a ~110.6 s 4-FSK frame out of the audio
  output for your radio to key via VOX. It keeps going, slot after slot, until you
  toggle it off.
- A live console (a **hideable bottom sheet** over the map/list) shows a countdown to
  the next transmission and a progress ring / time-remaining while on the air.
- The message is encoded on-device (callsign + grid + power → 162 symbols).

**Receive & report**
- Reports are shown on a **map** (band-coloured dots, tap for the propagation path) or
  as a **list** (heard station, reporter, band, SNR, distance, age).
- Two report sources: **internet** (the global WSPRnet database via
  [wspr.live](https://wspr.live)) and **radio** (decoded locally from your receiver's
  audio — see *Limitations*).

**Filtering** (all in the Filter sheet)
- **Source** — radio only, internet only, or both.
- **Only stations hearing me** — restrict to spots of *your* callsign being heard.
- **Time window** — last 4 / 8 / 16 / 32 / 64 / 128 min, 6 h, 12 h, 24 h, or a custom
  date range.
- **Band** — all bands or a single band.
- **Radius** — within N km of your station, your grid square, or any other grid square.

---

## Prior art & research

This app was designed after reviewing the established WSPR ecosystem:

- **WSPR / WSJT-X** (Joe Taylor, K1JT) — the reference implementation of the protocol.
  WSPR first appeared in November 2010. A message packs callsign, Maidenhead locator and
  power (dBm) into 50 bits, adds a K=32 rate-1/2 convolutional code (→162 bits),
  interleaves, and merges a 162-bit sync vector to form 162 four-level symbols. It is
  sent as continuous-phase 4-FSK at 1.4648 baud with 1.4648 Hz tone spacing, occupying
  ~6 Hz over ~110.6 s, starting one second into each even UTC minute.
  <https://en.wikipedia.org/wiki/WSPR_(amateur_radio_software)>
- **iWSPR TX** (IW2MVI) — established iOS app proving the "phone audio → cable → radio,
  keyed by VOX" transmit approach this app follows.
- **WSPR Watch** — popular iOS reader of WSPRnet data; informed the filtering + map/list
  presentation. Its author notes phone transmit is best for quick acoustic antenna
  checks, with WSJT-X on a computer for serious operating — the same framing we use.
- **wspr.live** — a ClickHouse mirror of the WSPRnet spot archive with an open HTTP SQL
  API (`SELECT … FROM wspr.rx`). We query it bounded by time, band and station/region
  per its usage guidance. <https://wspr.live>
- **Etherkit JTEncode** — a widely used, WSJT-X-verified C encoder. `WSPRMessage.swift`
  is a faithful Swift port of its `wspr_encode` path (bit packing, convolution with
  generator polynomials `0xF2D05351` / `0xE4613C47`, bit-reversal interleave, sync merge).
- **G4JNT, "The WSPR Coding Process"** — the canonical description of the encoding used
  to cross-check the port.

---

## Project layout

```
WSPR.xcodeproj          Xcode 16 project (file-system-synchronized groups)
WSPR/
  WSPRApp.swift         App entry point; wires up shared state
  Models/               Report, Band, Power, SpotSource, ReportFilter, Maidenhead
  Encoding/
    WSPRMessage.swift   Callsign/grid/power → 162 WSPR symbols (JTEncode port)
  Audio/
    WSPRProtocolConstants.swift  Timing / slot math
    WSPRToneSynth.swift          Symbols → continuous-phase 4-FSK PCM buffer
    TransmitController.swift     Slot-aligned transmit state machine
    WSPRDecoder.swift            Decoder protocol + documented stub
    ReceiveController.swift      Mic capture, 2-min windowing → decoder
  Services/
    WSPRLiveClient.swift  wspr.live (ClickHouse) query builder + parser
    ReportsStore.swift    Merges internet + radio spots, applies filter
    LocationManager.swift CoreLocation → coordinate + grid
    SettingsStore.swift   Station identity + transmit defaults (UserDefaults)
  Views/                Root (map/list), Transmit sheet, Filter, Settings, detail
```

## Building

Open `WSPR.xcodeproj` in Xcode 16 or newer and run on an iOS 17+ device or simulator.
The project generates its own Info.plist; microphone and location usage strings and the
audio background mode are set in the build settings. No packages to resolve.

For real transmitting you need an amateur radio licence and a cable from the device's
audio output to your radio's mic/line input with VOX enabled. Set your callsign, grid
and band in Settings first.

## Limitations & honest notes

- **Local (radio) decoding is a scaffold.** The receive pipeline captures device audio
  and windows it to even-minute boundaries through a real `WSPRDecoder` interface, but
  the bundled decoder (`NullWSPRDecoder`) returns no spots. A full WSPR receiver needs a
  synchronised FFT front-end and a soft-decision Fano sequential decoder (as in WSJT-X's
  `wsprd`); that is intentionally out of scope here. Internet reporting is fully
  functional. Receiving is opt-in and labelled experimental in the UI.
- **Transmit is Type 1 only.** Standard callsign + 4-character grid + power. Compound /
  portable callsigns (with `/`) use WSPR's hashed Type 2/3 encoding and are rejected for
  transmit rather than sent incorrectly. They still display fine in reports.
- **No WSPRnet upload.** The app reads the network but does not upload spots; a real
  local decoder would be a prerequisite.
- This app was implemented against the Apple SDKs on Linux and has not yet been compiled
  in Xcode; treat the first build as a smoke test.

## Credits

WSPR was created by Joe Taylor, K1JT. Encoding follows WSJT-X and the Etherkit JTEncode
library. Report data is provided by the WSPRnet community via wspr.live.
