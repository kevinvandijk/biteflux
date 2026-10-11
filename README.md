# Biteflux

An iPhone app that scans what you eat (a nutrition label, a barcode or a product name),
keeps your food log, and saves every entry with its nutrients to Apple Health.
The look follows the B4 "Ember" design: dark and warm, serif numbers, plain-language sync status.

This is step 1 of the build: the app skeleton, the Today screen, and the Apple Health round trip.
Scanning comes later; for now "Scan something" opens a list of sample foods.

## Layout

- `Biteflux/` is the iOS app (SwiftUI, SwiftData, HealthKit, iOS 17+). Files in this folder are
  picked up by Xcode automatically.
  - `Health/HealthStore.swift` saves a food to Apple Health as one food entry with a sample per
    nutrient, reads it back, and deletes it.
  - `Health/EntryLogger.swift` keeps each entry in Biteflux first, then writes it to Apple Health
    and only marks it "In Apple Health" once it reads back. Retries never save the same entry twice.
  - `Today/` is the Today screen, `Theme/` the Ember colours and fonts.
- `BitefluxCore/` is a Swift package with the logic that doesn't need a phone: nutrient maths,
  kJ to kcal, salt to sodium, the meal for a time of day, and the day's totals.

## Build and test

Open `Biteflux.xcodeproj` in Xcode, pick your team under Signing & Capabilities, and run.

From the command line:

```sh
swift test --package-path BitefluxCore
xcodebuild -project Biteflux.xcodeproj -scheme Biteflux \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
```

The Apple Health round trip works in the iOS Simulator too: log a sample food, allow access,
and it shows up in the Simulator's Health app under Browse, Nutrition.

## Fonts

DM Serif Display and DM Sans are bundled under the SIL Open Font License; the licence texts are
next to the font files in `Biteflux/Fonts/`.
