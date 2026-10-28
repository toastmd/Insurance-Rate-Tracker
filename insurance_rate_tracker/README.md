# Insurance Rate Tracker (Flutter)

Track what you pay for each insurance policy, log quotes from other carriers,
and see who's cheapest and how rates change at renewal. One codebase for
Android phones and tablets, iPhone and iPad.

## What's in the app

- **Policies**: auto, home, renters, life, pet, umbrella and more, sorted by
  soonest renewal, with your total premium and potential savings at the top.
- **Policy page**: a bar comparison of each carrier's latest price, a
  rate-history chart, your percent change since the last renewal, and every
  entry (tap to edit or delete).
- **Carriers**: how often each company comes in lowest and how much its prices
  tend to rise per update.
- **Settings**: show prices per month or per year, currency, export a CSV
  spreadsheet or a JSON backup through the share sheet, import a backup, load
  sample data, erase everything.
- Phones use bottom navigation. iPads, Android tablets and wide windows get a
  side rail with the list and detail side by side. Light and dark mode follow
  the system.

Data is stored on the device with `shared_preferences`. Backup files use the
same format as the web version, so you can move data between them.

## Project layout

```
lib/
  main.dart                  app entry, theme, store provider
  models.dart                Policy, Quote, PolicyType, BillingPeriod
  store.dart                 data, persistence, comparisons, CSV/JSON, sample data
  format.dart                dates, money, number parsing
  theme.dart                 colors, fonts, carrier palette
  screens/
    home_screen.dart         adaptive navigation (bar on phones, rail on tablets)
    policies_screen.dart     summary, policy list, list+detail split on tablets
    policy_detail.dart       comparison, history chart, entries
    carriers_screen.dart     per-carrier stats
    settings_screen.dart     display options, export, import, reset
  widgets/
    common.dart              panels, chips, date and carrier fields, sheet layout
    policy_form.dart         add/edit policy sheet
    quote_form.dart          add/edit rate sheet
    rate_chart.dart          history chart (CustomPainter, no chart library)
    rate_ladder.dart         carrier comparison bars
test/
  widget_test.dart           unit tests for the math plus a smoke test
```

## Setup

You need Flutter 3.24 or newer (`flutter --version`). For iOS and iPadOS you
also need a Mac with Xcode; Android needs Android Studio or the Android SDK.

1. Unzip, then open a terminal in the `insurance_rate_tracker` folder.
2. Generate the native Android and iOS projects. This only adds missing
   files, so it won't touch `lib/` or `test/`:

   ```
   flutter create --platforms=android,ios --org com.yourname .
   ```

   Replace `com.yourname` with your own reverse domain; it becomes the bundle
   ID (`com.yourname.insurance_rate_tracker`).
3. Install packages and check everything:

   ```
   flutter pub get
   flutter analyze
   flutter test
   ```
4. Run it:

   ```
   flutter run                 # picks a connected device or simulator
   flutter devices             # list what's available
   ```

### iPad

The generated iOS project supports iPhone and iPad by default. To confirm, open
`ios/Runner.xcworkspace` in Xcode, select the Runner target, and check that
**Supported Destinations** lists iPad. Run on an iPad simulator to see the
side-by-side layout.

### App name

`flutter create` names the app `insurance_rate_tracker`. To show
"Insurance Rates" under the icon instead:

- Android: in `android/app/src/main/AndroidManifest.xml`, set
  `android:label="Insurance Rates"`.
- iOS: in `ios/Runner/Info.plist`, set `CFBundleDisplayName` to
  `Insurance Rates`.

### App icon (optional)

Add `flutter_launcher_icons` as a dev dependency, point it at a 1024x1024 PNG,
and run `dart run flutter_launcher_icons`.

### Fonts

The UI uses Bricolage Grotesque through `google_fonts`, downloaded on first
launch and cached. Offline on first launch, it falls back to the system font.
To bundle it instead, download the font files into `assets/fonts/`, list them
under `flutter: fonts:` in `pubspec.yaml`, and set
`GoogleFonts.config.allowRuntimeFetching = false` in `main()`.

## Release builds

- Android: `flutter build appbundle`, then upload the `.aab` in Google Play
  Console. Set up app signing first (see Flutter's "Build and release an
  Android app" guide).
- iOS/iPadOS: `flutter build ipa`, then upload with Xcode's Organizer or
  Transporter to App Store Connect. Requires an Apple Developer account.

## Ideas for next steps

- Cloud sync across devices (Firebase Firestore or Supabase), replacing the
  `shared_preferences` calls in `store.dart`.
- Renewal reminders with `flutter_local_notifications`.
- Attach photos of declaration pages to a quote.
