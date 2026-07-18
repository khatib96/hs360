# Phase 7 M10 — Map Provider Decision

**Status:** M10 CLOSED / ACCEPTED (2026-07-19)  
**Package:** `flutter_map` **8.3.1** (declared `^8.3.1`)  
**Coordinates helper:** `latlong2` **0.10.1** (declared `^0.10.1`)  
**License:** BSD-3-Clause (`flutter_map`)

## Why this stack

| Candidate | Decision |
|-----------|----------|
| **flutter_map + latlong2** | **Chosen.** Pure Flutter, Android / iOS / macOS / Windows, injectable raster tiles, fakeable without network, no Google Maps SDK key in source. |
| `google_maps_flutter` | Rejected — API keys, weak Windows desktop story, harder offline tests. |
| Mapbox / MapLibre SDKs | Rejected — access tokens and heavier vendor lock-in for display-only Route View. |

Pinned after `flutter pub get` on 2026-07-19: `flutter_map 8.3.1`, `latlong2 0.10.1`
(see `pubspec.lock`).

### Smoke skip matrix (this workstation, 2026-07-19)

| Platform | Result |
|----------|--------|
| Android emulator + tiles | **Skipped** — no tile dart-defines / device session in this run |
| Windows host + tiles | **Skipped** — local host is macOS (not a blocker) |
| Fake deterministic screenshots | **Passed** — `build/screenshots/m10_*.png` (17 frames) |

Do **not** ship `tile.openstreetmap.org` as the production default.

Configure at build/run time only (never commit tokens):

```text
--dart-define=HS360_MAP_TILE_URL_TEMPLATE=https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key={key}
--dart-define=HS360_MAP_TILE_API_KEY=<restricted-public-client-token>
--dart-define=HS360_MAP_ATTRIBUTION=© MapTiler © OpenStreetMap contributors
```

Supported template placeholders: `{z}`, `{x}`, `{y}`, and optional `{key}` substituted from `HS360_MAP_TILE_API_KEY`.

If the template is missing or invalid, Route View enters a **tile-failure** state. The event **list remains fully usable**.

## Tile API key = restricted public client token

The key is extractable from the app binary. Treat it as a **restricted public client token**, not a server secret:

- Restrict by HTTP referrer / app package / IP at the provider console.
- Rotate on leakage or schedule.
- Monitor quota and rate limits.
- Privacy: the tile provider sees **viewport tile z/x/y HTTP requests only**. HS360 does **not** send marker, customer, or event metadata to the tile host.

## User-Agent, caching, attribution

- HTTP **User-Agent** identifies HS360 (`com.hs360.app` / package name string used by `TileLayer.userAgentPackageName`).
- **Caching:** use only the provider/client’s normal **bounded HTTP** tile cache. M10 does **not** add an offline tile-download/store package.
- Show required **attribution** whenever tiles are displayed (OSM data attribution + configured provider name).

## Public OSM tiles

Allowed **only** for low-volume **manual development smoke**, with full [OSM Tile Usage Policy](https://operations.osmfoundation.org/policies/tiles/) compliance (identified User-Agent, attribution, no bulk abuse). Never the shipped production configuration.

## Automated tests vs manual smoke

| Evidence | Rule |
|----------|------|
| Widget / screenshot tests | **FakeCalendarMapSurface** only — zero network tiles. |
| Android production-adapter smoke | Run only when emulator/device **and** tile dart-defines are available. |
| Windows production-adapter smoke | Run only on a Windows host or suitable CI runner. |
| Missing host / device / tiles | Record as **skipped** — not an M10 implementation blocker. |

Fake screenshots alone are **not** proof of real `flutter_map` tile integration.

### Smoke skip matrix (this workstation)

| Platform | Result |
|----------|--------|
| Android emulator + tiles | Skipped unless device and dart-defines present |
| Windows host + tiles | Skipped on macOS local host (not a blocker) |
| Fake deterministic screenshots | Required for M10 automated evidence |

## Route View data vs tiles

Map markers use validated coordinates from `get_calendar_route_day` (`location_state = mapped` only). Directions targets come from `get_calendar_event_directions`. Tile requests never include those payloads.
