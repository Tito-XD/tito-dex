# TitoDex Launcher

Read `../docs/AI_CONTEXT.md`, `../docs/DESIGN_SYSTEM.md`, then `README.md` and `HANDOFF.md`.

This independent Android launcher is explicitly authorized product scope. Keep changes in `launcher/`; do not turn the existing TitoDex host APK into a launcher or change its release version. Package IDs are `com.tito.titodex.launcher` (home) and `com.tito.titodex` (fixed companion entry).

Preserve Chinese UI, the three existing theme identities, local-only preferences and opt-in city weather. Never fabricate weather, infer private trainer data, automatically replace the default HOME app, or change the system wallpaper. Keep Android HOME/back behavior, D-pad focus, and access to alternate home/system settings working.

Check `flutter analyze` and `flutter test`. Device validation is separately recorded from widget tests. Local preview builds use the debug signer; do not label them public production releases.

For real-device integration testing, use `tool/test_device.py <serial>` with `JAVA_HOME` configured. It backs up private preferences/wallpaper, passes `--no-uninstall`, and restores then verifies the backup. Flutter's default integration test cleanup uninstalls the app and erases user preferences; never omit this protection. Keep backups private under ignored `build/validation/`.
