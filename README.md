# Geocent

Geocent is a personal finance app for Android that turns M-PESA and bank SMS into a map of where your money goes. It reads financial SMS as they arrive, tags each payment with where you were, and gives you budgets, analytics and alerts. Everything stays on your phone.

Android only: iOS does not let apps read SMS.

## Features

- **Automatic tracking:** M-PESA (sent, paid, airtime) and Equity Bank card SMS are parsed as they arrive, even with the app closed. USD charges are kept separate from KES.
- **Location tagging:** each new payment is tagged with your location. Imported or untagged payments can be placed on a map later, one at a time or in bulk.
- **Opt-in import:** on first launch, choose how much SMS history to import (none, 7 days, 30 days, 3 months or everything). You can import again from Profile.
- **Map:** today's spending as price-tag markers on OpenStreetMap.
  - Long-press anywhere to see what you've spent within a radius (100 m to 2 km).
  - Light, Standard and Dark styles.
- **Messages:** triage payments that still need a location or category, with search, filters and multi-select.
- **Categories:** auto-categorisation learned from your choices; add or delete your own.
- **Budgets:** daily, weekly (Sunday start) or monthly limits per category, with alerts at 50%, 80% and 100%.
- **Analytics:** week, month or year totals with trend, stacked bar, line and donut charts, category and recipient breakdowns, and quick insights.
- **Spending hotspots:** places you spend often are learned automatically. Lingering in one for 5 minutes sends a heads-up (at most every 6 hours).

## Getting started

### Requirements

- Android Studio, or the Android SDK command-line tools
- **JDK 21**
- **Android SDK platform 37.2**: `sdkmanager "platforms/android-37.2"`
- A device or emulator running Android 8.0 (API 26) or newer

No map account or API key is needed. Maps use OpenStreetMap data served by [OpenFreeMap](https://openfreemap.org).

### Build and run

```bash
git clone https://github.com/H-Munene/geocent.git
cd geocent
./gradlew installDebug      # build and install on a connected device
./gradlew testDebugUnitTest # run the unit tests
```

### Trying it on an emulator

```bash
adb emu sms send MPESA "UDR0H250GJ Confirmed. Ksh750.00 paid to JAVA HOUSE. on 27/11/26 at 7:58 AM. New M-PESA balance is Ksh1,037.84."
adb emu geo fix 36.8172 -1.2864   # longitude latitude: Nairobi CBD
```

## Supported SMS formats

- **M-PESA:** sent money, paid bills/merchants, airtime purchases
- **Equity Bank:** card authorisations in KES and USD

The parser lives in `app/src/main/java/app/geocent/domain/SmsParser.kt` and has tests in `app/src/test/java/app/geocent/domain/SmsParserTest.kt`.

## Tech stack

| Concern | Choice |
|---|---|
| Language / UI | Kotlin, Jetpack Compose |
| Architecture | ViewModel + StateFlow, Hilt |
| Storage | Room (SQLite), DataStore |
| Background work | WorkManager (expedited for SMS) |
| Location | Play Services fused location and geofencing |
| Maps | MapLibre Native with OpenFreeMap styles |
| Charts | Drawn with Compose Canvas |
| Icons / fonts | Hugeicons (generated vectors), Space Grotesk, Inter |

## Documentation

- [Technical architecture](docs/TECHNICAL_ARCHITECTURE.md)
- [Database schema](docs/DATABASE_SCHEMA.md)
- [Design principles](DESIGN.md)

To regenerate the category and UI icons, run `tools/gen_icons.py` against the Hugeicons package data (see the script's header).
