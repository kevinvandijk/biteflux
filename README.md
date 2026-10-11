# Biteflux

An iPhone app that scans what you eat (a nutrition label, a barcode or a product name),
keeps your food log, and saves every entry with its nutrients to Apple Health.
The look follows the B4 "Ember" design: dark and warm, serif numbers, plain-language sync status.

Built so far: the app skeleton, the Today screen and the Apple Health round trip (step 1), and the
product library (step 2). Scanning comes in step 3; until then "Scan something" opens the library,
where you look up a barcode by typing its number, find a product you added before, or add one by
copying its label.

## Layout

- `Biteflux/` is the iOS app (SwiftUI, SwiftData, HealthKit, iOS 17+). Files in this folder are
  picked up by Xcode automatically.
  - `Health/HealthStore.swift` saves a food to Apple Health as one food entry with a sample per
    nutrient, reads it back, and deletes it.
  - `Health/EntryLogger.swift` keeps each entry in Biteflux first, then writes it to Apple Health
    and only marks it "In Apple Health" once it reads back. Retries never save the same entry twice.
  - `Library/` is the product library: barcode lookup on Open Food Facts, your own products, and
    the screen where you pick a portion and log it. Products keep nutrients per 100 g; each entry
    keeps its own copy, so editing or removing a product never changes your log.
  - `Today/` is the Today screen, `Theme/` the Ember colours and fonts.
- `BitefluxCore/` is a Swift package with the logic that doesn't need a phone: nutrient maths,
  kJ to kcal, salt to sodium, the meal for a time of day, the day's totals, reading Open Food Facts
  answers, barcode check digits, and search.

## Build and test

Open `Biteflux.xcodeproj` in Xcode, pick your team under Signing & Capabilities, and run.

From the command line:

```sh
swift test --package-path BitefluxCore
xcodebuild -project Biteflux.xcodeproj -scheme Biteflux \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
```

The Apple Health round trip works in the iOS Simulator too: log a food, allow access, and it shows
up in the Simulator's Health app under Browse, Nutrition. Barcode lookups need an internet
connection; 3017624010701 (Nutella) is a known product to try.

## Data sources

Barcode lookups use [Open Food Facts](https://world.openfoodfacts.org), whose data is available
under the [Open Database License](https://opendatacommons.org/licenses/odbl/1-0/). Its values are
crowd-sourced, so Biteflux shows them for a check against the label before you log a product.

## Fonts

DM Serif Display and DM Sans are bundled under the SIL Open Font License; the licence texts are
next to the font files in `Biteflux/Fonts/`.
