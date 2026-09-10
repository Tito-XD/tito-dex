# Trainer's Journal checks

Run the portable regression tests from `flutter/`:

```sh
flutter test --no-pub test/trainer_journal_test.dart
```

These checks load the four bundled Nunito cuts, set the actual `AppLocale`
for English cases, and inspect rendered text transforms at 100%, 130%, and
200% text scaling. They also cover default phone/handheld card dimensions and
shared styles in all three themes. No app fonts or font weights are added.

Component PNG capture is opt-in because Flutter's widget-test engine has no
system CJK fallback. Supply a local Chinese-capable font, for example on Windows:

```powershell
flutter test --no-pub test/trainer_journal_test.dart --plain-name 'writes Journal / Plastic / Flat home previews' --dart-define=JOURNAL_PREVIEW_CJK_FONT=C:/Windows/Fonts/msyh.ttc
```

The capture loads Material Icons and registers the supplied font under the
existing CJK fallback family **only in the test engine**. It does not copy or
redistribute the font. Without the path, the capture test is skipped; ordinary
regression checks still run. An invalid path fails the capture.

Output: `build/journal-preview/{classic,solidPlastic,flatUi,journal-team-journey,journal-handheld}.png`.
These are component compositions with mock data, transparent margins, and
letter/skeleton sprite fallbacks. They are not complete Home pages or Android
screenshots; host CJK glyphs can differ from the device's font. Native-device
visual acceptance remains separate.
