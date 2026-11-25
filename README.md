# Otomater B2B Field App (Flutter)

Android + iOS app for Logic School of Management's B2B Marketing team:
today's/upcoming visits, real-phone-GPS Check In, and Mark Visit Done
(activity type, remarks, follow-up, contacts met - existing or new) -
talking to your Odoo 19 `otm_b2b_marketing` install through the new
`otm_b2b_mobile_api` backend module included alongside this app.

## 1. Install the backend module first

1. Copy `otm_b2b_mobile_api/` into your Odoo `addons` folder, next to
   `otm_b2b_marketing`.
2. Apps > Update Apps List > search "Otomater B2B Marketing - Mobile API" > Install.
3. Nothing else to configure. Every user who can already use the B2B
   Marketing app in the browser can log in from the phone with the same
   email + password.
4. (Optional) B2B Marketing > Configuration > Mobile App Sessions shows
   every phone currently logged in, and lets a Marketing Head sign one out
   instantly (e.g. a lost phone) by deleting its row.

## 2. Get the Flutter app running on your machine

This zip contains the app's full Dart source (`lib/`), its dependency list
(`pubspec.yaml`), and a working Android project. It was built without a
Flutter SDK available in the environment that generated it, so before you
can run or build it you need Flutter installed on your own computer (this
is a one-time setup, standard for any Flutter project - it's not specific
to this app):

1. Install Flutter: https://docs.flutter.dev/get-started/install
2. Unzip this project, then from inside its folder run:
   ```
   flutter pub get
   flutter create .
   ```
   `flutter create .` is safe to run on an existing project - it never
   touches `lib/` or `pubspec.yaml`, it only fills in/repairs the native
   Android and iOS scaffolding (Gradle wrapper files, the Xcode project,
   app icons) to match the Flutter version on your machine.
3. Run on a connected Android phone (USB debugging on) or emulator:
   ```
   flutter run
   ```
4. Build an installable Android APK:
   ```
   flutter build apk --release
   ```
   The APK lands at `build/app/outputs/flutter-apk/app-release.apk` -
   copy it to a phone and install it directly, no Play Store needed for
   internal use (the phone will ask to allow "install from unknown
   sources" the first time).
5. iOS needs a Mac with Xcode (Apple does not allow building iOS apps
   anywhere else): open `ios/Runner.xcworkspace` in Xcode after step 2,
   set your own Apple Developer signing team under
   Runner > Signing & Capabilities, then Product > Run (to a connected
   iPhone) or Product > Archive (to install via TestFlight/ad-hoc, again
   no App Store listing needed for internal use).

## 3. Using the app

- **Login screen** asks for: Server URL (e.g. `https://erp.otomater.com`),
  Database name, and the same email/password used in the browser.
- **Home** shows the same numbers as the web Dashboard: Today's Visits,
  Upcoming Visits, High Priority institutions, My Institutions.
- **Check In** captures the phone's actual GPS coordinates at the moment
  of tapping the button (with a permission prompt the first time) - this
  is the fix for the earlier issue where visits created from the desktop
  browser never had a location, since a desktop has no GPS to ask.
- **Complete Visit** shows the institution's saved contacts as checkboxes
  (tick everyone met) plus "Add another contact" for anyone new - new
  contacts are saved to that institution's directory automatically, so
  they show up as existing contacts on the next visit too, exactly like
  the "Mark visit done" portal form.

## Notes / things to adjust before wider rollout

- App icon is a plain placeholder circle - swap the PNGs under
  `android/app/src/main/res/mipmap-*/ic_launcher.png` (and, once
  `flutter create .` has generated it, `ios/Runner/Assets.xcassets`) for
  Otomater's real logo.
- `android/app/build.gradle`'s release build currently signs with the
  Android debug key so `flutter build apk --release` works immediately for
  internal testing - set up your own release keystore before distributing
  outside the team.
- iOS `Info.plist` currently allows plain HTTP (`NSAllowsArbitraryLoads`)
  in case your Odoo server isn't on HTTPS yet - remove that once it is, for
  a tighter App Transport Security policy.
- The mobile API's device tokens do not expire on their own; revoke them
  from Mobile App Sessions in the backend if a phone changes hands.
