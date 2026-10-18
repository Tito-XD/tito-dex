# TitoDex Launcher

Read `../docs/AI_CONTEXT.md`, `../docs/DESIGN_SYSTEM.md`, then `README.md` and `HANDOFF.md`.

This independent Android launcher is explicitly authorized product scope. Keep changes in `launcher/`; do not turn the existing TitoDex host APK into a launcher or change its release version. Package IDs are `com.tito.titodex.launcher` (home) and `com.tito.titodex` (fixed companion entry).

Preserve Chinese UI, the three existing theme identities, local-only preferences and opt-in city weather. Never fabricate weather, infer private trainer data, automatically replace the default HOME app, or change the system wallpaper. Keep Android HOME/back behavior, D-pad focus, and access to alternate home/system settings working.

The Launcher UI is native Kotlin + Jetpack Compose (the companion App remains Flutter). Check `./gradlew --no-daemon --max-workers=2 :app:testDebugUnitTest :app:assembleRelease`. Use the bounded JVM/worker settings in gradle.properties; do not build this and the Flutter App concurrently. Device validation is separate from JVM/Robolectric tests. Local preview builds use the debug signer; do not label them public production releases.

For real-device smoke testing, use `tool/test_device.py <serial> --apk <apk> --debug-apk <same-version-debug-apk>` with JAVA_HOME and ANDROID_HOME configured. It backs up private preferences/wallpaper, uses only install -r, and restores then verifies the backup. Non-debuggable release builds require the same-signer debug sibling for run-as access, then the target APK is reinstalled. Never uninstall, clear data, or run automatic uninstalling test tasks on the user device. Keep backups and wallpaper screenshots private under ignored build/validation/. Android system widget hosting is user-authorized in 0.3; preserve host IDs and undo behavior.
