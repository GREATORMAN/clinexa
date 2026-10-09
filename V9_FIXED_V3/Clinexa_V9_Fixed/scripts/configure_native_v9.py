"""Idempotent Android setup for Clinexa V9.

Preserves package/signing configuration while applying reminder permissions,
core-library desugaring and a consistent JVM 11 target for the app and Flutter
plugin subprojects. The JVM normalization prevents Gradle failures such as:
compileDebugJavaWithJavac (11) vs compileDebugKotlin (1.8).
"""
from pathlib import Path
import re
import xml.etree.ElementTree as ET


def manifest_text(text: str) -> str:
    for permission in ["POST_NOTIFICATIONS", "RECEIVE_BOOT_COMPLETED"]:
        full = "android.permission." + permission
        if full not in text:
            text = text.replace(
                "<application",
                f'<uses-permission android:name="{full}" />\n    <application',
                1,
            )

    if "android:allowBackup" not in text:
        text = text.replace("<application", '<application android:allowBackup="false"', 1)

    prefix = "com.dexterous.flutterlocalnotifications."
    scheduled = prefix + "ScheduledNotificationReceiver"
    boot = prefix + "ScheduledNotificationBootReceiver"

    if scheduled not in text:
        text = text.replace(
            "</application>",
            f'<receiver android:exported="false" android:name="{scheduled}" />\n</application>',
            1,
        )

    if boot not in text:
        text = text.replace(
            "</application>",
            (
                f'<receiver android:exported="false" android:name="{boot}">'
                '<intent-filter>'
                '<action android:name="android.intent.action.BOOT_COMPLETED"/>'
                '<action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>'
                '</intent-filter>'
                '</receiver>\n</application>'
            ),
            1,
        )

    ET.fromstring(text)
    return text


def app_gradle_text(text: str, kotlin: bool) -> str:
    """Normalize the app module without replacing package/signing settings."""
    if kotlin:
        flag = "isCoreLibraryDesugaringEnabled = true"
        pattern = r"isCoreLibraryDesugaringEnabled\s*=\s*(?:true|false)"
    else:
        flag = "coreLibraryDesugaringEnabled true"
        pattern = r"coreLibraryDesugaringEnabled\s*(?:=\s*)?(?:true|false)"

    if re.search(pattern, text):
        text = re.sub(pattern, flag, text)
    else:
        if "compileOptions {" not in text:
            raise ValueError("No compileOptions block found; configure desugaring manually before retrying.")
        text = text.replace("compileOptions {", "compileOptions {\n        " + flag, 1)

    if kotlin:
        text = re.sub(
            r"sourceCompatibility\s*=\s*JavaVersion\.VERSION_\d+",
            "sourceCompatibility = JavaVersion.VERSION_11",
            text,
        )
        text = re.sub(
            r"targetCompatibility\s*=\s*JavaVersion\.VERSION_\d+",
            "targetCompatibility = JavaVersion.VERSION_11",
            text,
        )
        text = re.sub(r"JvmTarget\.JVM_\d+", "JvmTarget.JVM_11", text)
        text = re.sub(r'jvmTarget\s*=\s*["\'](?:1\.8|8|11|17|21)["\']', 'jvmTarget = "11"', text)

        if "sourceCompatibility" not in text or "targetCompatibility" not in text:
            text = text.replace(
                "compileOptions {",
                "compileOptions {\n"
                "        sourceCompatibility = JavaVersion.VERSION_11\n"
                "        targetCompatibility = JavaVersion.VERSION_11",
                1,
            )

        if not re.search(r"\bjvmTarget\b", text):
            text += (
                "\n\nkotlin {\n"
                "    compilerOptions {\n"
                "        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)\n"
                "    }\n"
                "}\n"
            )
    else:
        text = re.sub(
            r"sourceCompatibility\s*(?:=\s*)?(?:JavaVersion\.)?VERSION_\d+",
            "sourceCompatibility JavaVersion.VERSION_11",
            text,
        )
        text = re.sub(
            r"targetCompatibility\s*(?:=\s*)?(?:JavaVersion\.)?VERSION_\d+",
            "targetCompatibility JavaVersion.VERSION_11",
            text,
        )

        if "sourceCompatibility" not in text or "targetCompatibility" not in text:
            text = text.replace(
                "compileOptions {",
                "compileOptions {\n"
                "        sourceCompatibility JavaVersion.VERSION_11\n"
                "        targetCompatibility JavaVersion.VERSION_11",
                1,
            )

    dependency_pattern = r"\bcoreLibraryDesugaring\s*[\(\s][\s\'\"]*com\.android\.tools:desugar_jdk_libs"
    if not re.search(dependency_pattern, text):
        dependency = (
            'coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")'
            if kotlin
            else "coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'"
        )
        text += "\ndependencies {\n    " + dependency + "\n}\n"

    if kotlin:
        text = re.sub(
            r"compileSdk\s*=\s*flutter\.compileSdkVersion",
            "compileSdk = maxOf(35, flutter.compileSdkVersion)",
            text,
        )
        text = re.sub(
            r"compileSdk\s*=\s*(\d+)",
            lambda m: "compileSdk = " + str(max(35, int(m.group(1)))),
            text,
        )
    else:
        text = re.sub(
            r"compileSdk(?:Version)?\s+(?:=\s*)?flutter\.compileSdkVersion",
            "compileSdkVersion Math.max(35, flutter.compileSdkVersion)",
            text,
        )
        text = re.sub(
            r"compileSdk(?:Version)?\s+(?:=\s*)?(\d+)",
            lambda m: "compileSdkVersion " + str(max(35, int(m.group(1)))),
            text,
        )

    return text



def gradle_text(text: str, kotlin: bool) -> str:
    """Backward-compatible installer helper used by the V9 regression tests.

    V9 originally exposed this transformer as ``gradle_text``.  Keep the public
    helper name while delegating to the more explicit app-module transformer so
    older installers/tests and existing automation continue to work.
    """
    return app_gradle_text(text, kotlin)

def root_gradle_text(text: str, kotlin: bool) -> str:
    """Align JVM bytecode targets for app and Flutter plugin subprojects.

    This function is intentionally migration-safe. Earlier V9 hotfixes wrote
    ``kotlinOptions { jvmTarget = "11" }`` into the root Kotlin DSL file.
    Kotlin/Gradle versions used by current Flutter treat that deprecated DSL as
    a script-compilation error, so an already-marked project must be upgraded
    rather than skipped.
    """
    marker = "CLINEXA_JVM_TARGET_FIX_V9"

    if kotlin:
        imports = [
            "import org.gradle.api.tasks.compile.JavaCompile",
            "import org.jetbrains.kotlin.gradle.dsl.JvmTarget",
            "import org.jetbrains.kotlin.gradle.tasks.KotlinCompile",
        ]
        prefix = ""
        for item in imports:
            if item not in text:
                prefix += item + "\n"
        if prefix:
            text = prefix + "\n" + text

        # Upgrade legacy Kotlin compile-task DSL written by early V9 fixes.
        # Handle both block and property forms while preserving unrelated code.
        legacy_block = re.compile(
            r"kotlinOptions\s*\{\s*"
            r"jvmTarget\s*=\s*[\"\'](?:1\.8|8|11|17|21)[\"\']\s*"
            r"\}",
            re.DOTALL,
        )
        text = legacy_block.sub(
            "compilerOptions {\n            jvmTarget.set(JvmTarget.JVM_11)\n        }",
            text,
        )
        text = re.sub(
            r"kotlinOptions\.jvmTarget\s*=\s*[\"\'](?:1\.8|8|11|17|21)[\"\']",
            "compilerOptions.jvmTarget.set(JvmTarget.JVM_11)",
            text,
        )

        # If an earlier Clinexa block is already present, the migration above
        # makes it compatible with modern Kotlin DSL. Do not append a duplicate.
        if marker in text:
            return text

        block = f'''\n\n// {marker}\nsubprojects {{\n    tasks.withType<JavaCompile>().configureEach {{\n        sourceCompatibility = "11"\n        targetCompatibility = "11"\n    }}\n    tasks.withType<KotlinCompile>().configureEach {{\n        compilerOptions {{\n            jvmTarget.set(JvmTarget.JVM_11)\n        }}\n    }}\n}}\n'''
    else:
        if marker in text:
            return text
        block = f'''\n\n// {marker}\nsubprojects {{\n    tasks.withType(JavaCompile).configureEach {{\n        sourceCompatibility = "11"\n        targetCompatibility = "11"\n    }}\n    tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile).configureEach {{\n        kotlinOptions.jvmTarget = "11"\n    }}\n}}\n'''

    return text.rstrip() + block


def write_with_backup(path: Path, text: str) -> None:
    backup = path.with_name(path.name + ".pre_v9")
    if not backup.exists():
        backup.write_bytes(path.read_bytes())
    path.write_text(text, encoding="utf-8")


def configure(root: Path) -> None:
    changes: list[tuple[Path, str]] = []

    manifest = root / "frontend/android/app/src/main/AndroidManifest.xml"
    if manifest.exists():
        changes.append((manifest, manifest_text(manifest.read_text(encoding="utf-8-sig"))))

    for name in ["build.gradle.kts", "build.gradle"]:
        path = root / "frontend/android/app" / name
        if path.exists():
            changes.append((path, app_gradle_text(path.read_text(encoding="utf-8"), name.endswith(".kts"))))

    for name in ["build.gradle.kts", "build.gradle"]:
        path = root / "frontend/android" / name
        if path.exists():
            changes.append((path, root_gradle_text(path.read_text(encoding="utf-8"), name.endswith(".kts"))))

    for path, text in changes:
        write_with_backup(path, text)

    print("Android reminders and JVM target compatibility configured. iOS still requires its documented platform steps.")


if __name__ == "__main__":
    configure(Path(__file__).resolve().parent.parent)
