# Biteflux

An iPhone app that scans what you eat (a nutrition label, a barcode or a product name),
keeps your food log, and saves every entry with its nutrients to Apple Health.
The look follows the B4 "Ember" design: dark and warm, serif numbers, plain-language sync status.

Built so far: the app skeleton, the Today screen and the Apple Health round trip (step 1), the
product library (step 2), and scanning (step 3). "Scan something" opens the camera, which reads a
barcode, a product name you tap on the pack, or a photo of the nutrition label. A barcode is looked
up on Open Food Facts, a name is searched in your products, the Dutch food table (NEVO) and Open
Food Facts, and a label photo fills in a new product for you to check. You can also type or search
instead.

## Layout

- `Biteflux/` is the iOS app (SwiftUI, SwiftData, HealthKit, iOS 17+). Files in this folder are
  picked up by Xcode automatically.
  - `Health/HealthStore.swift` saves a food to Apple Health as one food entry with a sample per
    nutrient, reads it back, and deletes it.
  - `Health/EntryLogger.swift` keeps each entry in Biteflux first, then writes it to Apple Health
    and only marks it "In Apple Health" once it reads back. Retries never save the same entry twice.
  - `Library/` is the product library: barcode lookup on Open Food Facts, NEVO search, your own
    products, and the screen where you pick a portion and log it. Products keep nutrients per
    100 g; each entry keeps its own copy, so editing or removing a product never changes your log.
  - `Scan/` is the Scan screen (Apple's live text and barcode scanner) and label reading with
    Claude.
  - `Today/` is the Today screen, `Theme/` the Ember colours and fonts.
- `BitefluxCore/` is a Swift package with the logic that doesn't need a phone: nutrient maths,
  kJ to kcal, salt to sodium, the meal for a time of day, the day's totals, reading Open Food Facts
  answers and the NEVO table, the label reading request and answer, barcode check digits, and
  search.

## Build and test

Open `Biteflux.xcodeproj` in Xcode, pick your team under Signing & Capabilities, and run.

From the command line:

```sh
swift test --package-path BitefluxCore
xcodebuild -project Biteflux.xcodeproj -scheme Biteflux \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
```

To check the parser against the real NEVO table as well, point `NEVO_CSV` at it. The tests run
inside `BitefluxCore/`, so give the full path:

```sh
NEVO_CSV="$PWD/Biteflux/NEVO/NEVO2025_v9.0.csv" swift test --package-path BitefluxCore
```

The Apple Health round trip works in the iOS Simulator too: log a food, allow access, and it shows
up in the Simulator's Health app under Browse, Nutrition. Barcode lookups need an internet
connection; 3017624010701 (Nutella) is a known product to try. The Simulator has no camera, so the
Scan screen offers to read a label from a photo instead.

## Reading labels

Label photos are read by Claude, Anthropic's AI model, through the Anthropic API with your own API
key. The first time you read a label, Biteflux asks for the key (get one at
[console.anthropic.com](https://console.anthropic.com/settings/keys)) and keeps it in the
iPhone's Keychain; it is never part of this repository. Each photo costs a little on your Anthropic
account. Claude copies the numbers as printed, Biteflux works them out per 100 g, and values Claude
could only partly read are highlighted in the product form for you to check.

## Data sources

Barcode lookups and product name searches use [Open Food Facts](https://world.openfoodfacts.org),
whose data is available under the [Open Database License](https://opendatacommons.org/licenses/odbl/1-0/).
Its values are crowd-sourced, so Biteflux shows them for a check against the label before you log a
product.

Unbranded foods come from [NEVO-online](https://www.rivm.nl/en/dutch-food-composition-database),
the Dutch food composition table by RIVM. Based on data from NEVO online version 2025/9.0, RIVM,
Bilthoven. RIVM hands the table out to people who accept its conditions (values unchanged, the
source named wherever they're shown, no charge to users), so it isn't in this public repository.
To include it in your build:

1. Accept the conditions and download the dataset from
   [RIVM's request page](https://www.rivm.nl/en/dutch-food-composition-database/use-of-nevo-online/request-dataset).
2. Put `NEVO2025_v9.0.csv` in `Biteflux/NEVO/`. That folder is ignored by git, and Xcode bundles
   what's in it.

Without the file the app works the same, just without NEVO search.

## Fonts

DM Serif Display and DM Sans are bundled under the SIL Open Font License; the licence texts are
next to the font files in `Biteflux/Fonts/`.
