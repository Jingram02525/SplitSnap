# SplitSnap

Snap the receipt. Split the bill. Skip the math.

An iPhone app for splitting a restaurant bill by what each person actually ordered, including tax and tip.

## Getting started

1. Open `SplitSnap.xcodeproj` in **Xcode 16 or later**.
2. Select the **SplitSnap** target → *Signing & Capabilities* → choose your Team.
   (Change the bundle ID `org.firmecoding.SplitSnap` if needed.)
3. Run on an iPhone simulator (iOS 18+) with ⌘R.
4. Run the tests with ⌘U.

The project uses folder-synchronized groups, so files you add to `SplitSnap/` or
`SplitSnapTests/` in Finder show up in Xcode automatically.

## Structure

```
SplitSnap/
├── App/SplitSnapApp.swift        Entry point
├── Logic/
│   ├── Money.swift               Integer-cents money: parsing + formatting
│   ├── ReceiptParser.swift       Receipt text → items, subtotal, tax, total (pure)
│   └── SplitCalculator.swift     Pure split engine: itemized + even (no UI)
├── Models/Bill.swift             @Observable bill state: mode, people, items, tax, tip
├── Scanning/
│   ├── DocumentScannerView.swift VisionKit document camera wrapper
│   ├── ReceiptTextRecognizer.swift  Vision OCR → text fragments
│   └── ReceiptScanner.swift      Scan flow state + sheets (camera / photo → review)
└── Views/
    ├── BillEditorView.swift      Main screen + sticky "Split" button
    ├── PeopleSection.swift       Add names quickly (keyboard stays up)
    ├── ItemsSection.swift        Item rows with tap-to-assign name chips,
    │                             quick-add row, edit sheet
    ├── TaxTipSection.swift       Tax amount, TipPicker, TotalsRow
    ├── EvenSplitSection.swift    Even mode: receipt total, optional tax, tip
    ├── ScanReviewView.swift      Confirm scanned items/totals before applying
    ├── CurrencyField.swift       Cents-bound decimal field
    ├── SummaryView.swift         Per-person totals + ShareLink
    └── PersonChip.swift          Name pill + color palette
SplitSnapTests/
├── SplitCalculatorTests.swift    Swift Testing: allocation, rounding, parsing
└── ReceiptParserTests.swift      Receipt parsing + even split
```

## How the math works

- All amounts are stored as **integer cents**. No floating-point drift.
- A shared item is split evenly among the people assigned to it.
- Tax and tip are split **in proportion to each person's item subtotal**.
- Tip is a percentage of the **pre-tax** subtotal.
- Rounding uses the largest-remainder method, so everyone's totals add up to
  the bill total exactly, to the cent.
- Unassigned items get their own bucket, so nobody pays tax on food they didn't
  order. The Split button stays disabled until every item has an owner.

## Receipt scanning

The scan button opens VisionKit's document camera (it crops and flattens the
receipt, and long receipts can be shot in several pages). Vision reads the text,
`ReceiptParser` stitches name/price fragments into rows and pulls out items,
subtotal, tax, gratuity and total, and a review sheet confirms it before
anything touches the bill. It flags when items don't add up to the printed
subtotal.

The simulator has no document camera, so the scan button falls back to the
photo library there. Drag a receipt photo onto the simulator to test.

## Roadmap

- [x] MVP: manual items, tap-to-assign, shared items, proportional tax/tip, share totals
- [x] Receipt scanning (VisionKit document camera + Vision OCR → review → items)
- [x] Even split mode (receipt total, optional tax, tip)
- [ ] Polish: app icon, haptics pass, VoiceOver labels, "Everyone pays even" shortcut
- [ ] Pro ($2.99 one-time): saved receipts, group history, reusable groups (SwiftData + StoreKit 2)

Goal: open the app to sharing everyone's totals in **under 60 seconds**.
