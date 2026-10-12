# Biteflux

An iPhone app that scans what you eat (a nutrition label, a barcode or a product name),
keeps your food log, and saves every entry with its nutrients to Apple Health.
The look follows the B4 "Ember" design: dark and warm, serif numbers, plain-language sync status.

Built so far: the app skeleton, the Today screen and the Apple Health round trip (step 1), the
product library (step 2), scanning (step 3), the Match and Create screens (step 4), and editing
what you logged plus your daily goal (step 5).
"Scan something" opens the camera, which reads a barcode, a product name you tap on the pack, or a
photo of the nutrition label. A barcode is looked up on Open Food Facts, a name is searched in your
products, the Dutch food table (NEVO) and Open Food Facts, and a label photo fills in a new product
for you to check. You can also type or search instead. A product you found opens on the Match
screen, where you turn the gram dial, pick the meal and log it; a new one opens on the Create
screen, which asks about any value that was hard to read and saves and logs it in one go. On Today,
tap a food to change the amount, meal or time, or delete it; Apple Health gets the same change. Tap
the headline to set your daily goal.

## Layout

- `Biteflux/` is the iOS app (SwiftUI, SwiftData, HealthKit, iOS 17+). Files in this folder are
  picked up by Xcode automatically.
  - `Health/HealthStore.swift` saves a food to Apple Health as one food entry with a sample per
    nutrient, reads it back, and deletes it.
  - `Health/EntryLogger.swift` keeps each entry in Biteflux first, then writes it to Apple Health
    and only marks it "In Apple Health" once it reads back. Retries never save the same entry twice.
    Apple Health can't edit a saved food, so a changed entry replaces its old Health entry.
  - `Library/` is the product library: barcode lookup on Open Food Facts, NEVO search, your own
    products, the Match screen with the gram dial, and the Create screen for a new product.
    Products keep nutrients per 100 g; each entry keeps its own copy, so editing or removing a
    product never changes your log.
  - `Scan/` is the Scan screen (Apple's live text and barcode scanner) and label reading with
    GPT Luna 6 through OpenRouter.
  - `Today/` is the Today screen, `Theme/` the Ember colours and fonts.
- `BitefluxCore/` is a Swift package with the logic that doesn't need a phone: nutrient maths,
  kJ to kcal, salt to sodium, the meal for a time of day, the day's totals, the gram dial,
  reading Open Food Facts answers and the NEVO table, the label reading request and answer,
  barcode check digits, and search.

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

To read real label photos the way the app does, put JPEG photos (at most 1568 pixels on the long
side; `sips -Z 1568 *.jpg` makes them so) in a folder outside the repository and run the live test
with your own OpenRouter key. Each photo costs a little on that key's account.

```sh
OPENROUTER_KEY=… LABEL_PHOTOS=/path/to/photos \
  swift test --package-path BitefluxCore --filter LabelReaderLiveTests
```

The Apple Health round trip works in the iOS Simulator too: log a food, allow access, and it shows
up in the Simulator's Health app under Browse, Nutrition. Barcode lookups need an internet
connection; 3017624010701 (Nutella) is a known product to try. The Simulator has no camera, so the
Scan screen offers to read a label from a photo instead.

## Reading labels

Label photos are read by OpenAI's GPT Luna 6 (`openai/gpt-6-luna`) through
[OpenRouter](https://openrouter.ai), with your own OpenRouter key. The first time you read a label,
Biteflux asks for the key (get one at [openrouter.ai/settings/keys](https://openrouter.ai/settings/keys))
and keeps it in the iPhone's Keychain; it is never part of this repository. Each photo costs a
fraction of a cent on your OpenRouter account. The model copies the numbers as printed, Biteflux
works them out per 100 g, and the Create screen asks you about any value the model could only
partly read.

## iCloud sync

Your log and library stay on the phone for now. The models are ready for iCloud (every property has
a default, nothing is unique), but sync needs the iCloud capability, which needs a paid Apple
developer account. To turn it on:

1. In Xcode, under Signing & Capabilities, pick the paid team, add iCloud with CloudKit and a
   container such as `iCloud.com.kevinvandijk.biteflux`, and add Background Modes with Remote
   notifications.
2. Set `BitefluxApp.iCloudContainer` to that container.
3. Before a TestFlight or App Store build, deploy the schema to production in the CloudKit Console;
   those builds use the production environment.

With sync on, the device that logged a food, or last changed it, is the one that writes it to
Apple Health. Apple Health's own sync brings it to your other devices, so they leave it alone and
nothing is counted twice. Each iPhone knows itself by an ID in its Keychain, which survives a
reinstall. A change made on another device goes to Apple Health through the writer, until the
writer has left the food alone for a day; then the device you change it on takes over. Deleting
works the same way: the food disappears from Biteflux at once, and the writer removes it from Apple
Health, or the device you deleted it on does once the writer has been quiet for a day. If food is
stuck waiting for a device that's gone, like an old phone, tap it on Today: a day after that device
last tried, "Save it from this iPhone" hands it to the phone you're using.

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
