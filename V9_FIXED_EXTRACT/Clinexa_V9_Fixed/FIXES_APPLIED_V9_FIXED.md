# Clinexa V9 Fixed Full Source

This package is the V9 source with the known Windows/Flutter/Android blockers observed during local verification corrected in the source itself.

## Fixes included

- Applied the full Flutter analyzer cleanup overlay that produced `No issues found!` on the user's Flutter 3.47.6 environment.
- Fixed non-constant default list parameters and all reported Dart analyzer warnings/infos from the V9 verification run.
- Fixed Alembic Windows SQLite URL `%` interpolation handling.
- Added `path_separator = os` to Alembic configuration.
- Normalized Android app Java and Kotlin bytecode targets to JVM 11.
- Normalized Java/Kotlin compile targets for Flutter Android plugin subprojects to JVM 11, addressing `compileDebugJavaWithJavac (11)` vs `compileDebugKotlin (1.8)` failures such as `flutter_timezone`.
- Updated `configure_native_v9.py` so the JVM-target fix is applied idempotently to an existing Clinexa native Android project during upgrade, while preserving package/signing configuration.
- Added backup coverage for Android Gradle and manifest files before an in-place upgrade.
- Added `INSTALL_AND_VERIFY_V9_FIXED.bat` for a backed-up install followed by the full V9 verifier.

## Already verified before this package was assembled

On the user's Windows machine after the Dart/Alembic fixes:

- Backend: 44 tests passed.
- Flutter analyzer: No issues found.
- Flutter widget tests: all tests passed.

The remaining observed build blocker at that point was the Android JVM target mismatch; this package contains the source/configuration fix for that mismatch.

## Verification requirement

This assembly environment does not have the Flutter SDK/Android SDK, so the final Gradle/APK build must still be run on the user's Windows machine. Use:

```bat
INSTALL_AND_VERIFY_V9_FIXED.bat
```

or after installation:

```bat
cd /d "C:\Users\VISHAL\Documents\pdd\Clinexa_Full_v2\Clinexa_Functional_v2"
scripts\VERIFY_CLINEXA_V9.bat
```

## Non-blocking warnings intentionally not mass-rewritten

- Python 3.14 `datetime.utcnow()` deprecation warnings remain. They are not test failures. A safe timezone migration should be done deliberately because Clinexa currently stores many naive UTC timestamps and a blind replacement could change comparison/storage semantics.
- The Starlette/TestClient `httpx` deprecation warning is dependency-level and non-blocking.
- Flutter warnings about plugins applying the Kotlin Gradle Plugin are future-compatibility notices; upgrading those plugins should be done with regression testing rather than blindly changing dependencies.
- Android SDK XML/tool-version warnings depend on the local Android Studio / command-line tools installation.

These warnings do not represent the Android JVM mismatch fixed by this package.
