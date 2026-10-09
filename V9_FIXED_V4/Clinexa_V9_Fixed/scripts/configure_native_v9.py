"""Idempotent Android setup for Clinexa V9.

Preserves package/signing configuration while applying reminder permissions,
core-library desugaring and a consistent JVM 17 target for the app and Flutter
plugin subprojects. The JVM normalization prevents Gradle failures such as:
mixed Java/Kotlin JVM targets across Flutter plugins.
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
            "sourceCompatibility = JavaVersion.VERSION_17",
            text,
        )
        text = re.sub(
            r"targetCompatibility\s*=\s*JavaVersion\.VERSION_\d+",
            "targetCompatibility = JavaVersion.VERSION_17",
            text,
        )
        text = re.sub(r"JvmTarget\.JVM_\d+", "JvmTarget.JVM_17", text)
        text = re.sub(r'jvmTarget\s*=\s*["\'](?:1\.8|8|11|17|21)["\']', 'jvmTarget = "17"', text)

        if "sourceCompatibility" not in text or "targetCompatibility" not in text:
            text = text.replace(
                "compileOptions {",
                "compileOptions {\n"
                "        sourceCompatibility = JavaVersion.VERSION_17\n"
                "        targetCompatibility = JavaVersion.VERSION_17",
                1,
            )

        if not re.search(r"\bjvmTarget\b", text):
            text += (
                "\n\nkotlin {\n"
                "    compilerOptions {\n"
                "        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)\n"
                "    }\n"
                "}\n"
            )
    else:
        text = re.sub(
            r"sourceCompatibility\s*(?:=\s*)?(?:JavaVersion\.)?VERSION_\d+",
            "sourceCompatibility JavaVersion.VERSION_17",
            text,
        )
        text = re.sub(
            r"targetCompatibility\s*(?:=\s*)?(?:JavaVersion\.)?VERSION_\d+",
            "targetCompatibility JavaVersion.VERSION_17",
            text,
        )

        if "sourceCompatibility" not in text or "targetCompatibility" not in text:
            text = text.replace(
                "compileOptions {",
                "compileOptions {\n"
                "        sourceCompatibility JavaVersion.VERSION_17\n"
                "        targetCompatibility JavaVersion.VERSION_17",
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



def _balanced_block_end(text: str, start: int) -> int:
    """Return index just after a Gradle {...} block beginning at/after start."""
    brace = text.find("{", start)
    if brace == -1:
        return start
    depth = 0
    i = brace
    while i < len(text):
        ch = text[i]
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return i + 1
        i += 1
    return len(text)


def _strip_previous_jvm_fix(text: str, marker: str) -> str:
    """Remove prior Clinexa JVM fix while preserving surrounding Gradle blocks."""
    marker_token = "// " + marker
    while marker_token in text:
        marker_pos = text.find(marker_token)
        line_end = text.find("\n", marker_pos)
        if line_end == -1:
            return text[:marker_pos].rstrip()

        pos = line_end + 1
        # Skip comments/blank lines belonging to the compatibility block.
        while pos < len(text):
            next_nl = text.find("\n", pos)
            if next_nl == -1:
                next_nl = len(text)
            line = text[pos:next_nl].strip()
            if not line or line.startswith("//"):
                pos = next_nl + (1 if next_nl < len(text) else 0)
                continue
            break

        # Top-level form: marker followed by subprojects { ... } or
        # gradle.projectsEvaluated { ... }.
        if text.startswith("subprojects", pos) or text.startswith("gradle.projectsEvaluated", pos):
            end = _balanced_block_end(text, pos)
            text = text[:marker_pos] + text[end:]
            continue

        # Embedded form: marker sits inside an existing subprojects block and
        # is followed by one or more tasks.withType<...> blocks. Remove only
        # those task blocks, leaving the surrounding subprojects closing brace.
        end = pos
        removed = False
        while end < len(text):
            p = end
            while p < len(text) and text[p].isspace():
                p += 1
            if text.startswith("tasks.withType", p):
                end = _balanced_block_end(text, p)
                removed = True
                continue
            break
        if removed:
            text = text[:marker_pos] + text[end:]
        else:
            # Unknown old shape: remove the marker line only rather than
            # truncating the file.
            text = text[:marker_pos] + text[line_end + 1:]
    return text


def root_gradle_text(text: str, kotlin: bool) -> str:
    """Align final Java/Kotlin bytecode targets for all Android subprojects.

    Flutter plugins can declare different JVM targets. Configure the final
    compile tasks after all projects are evaluated so plugin-level Gradle
    files cannot overwrite the Clinexa compatibility target later.
    """
    marker = "CLINEXA_JVM_TARGET_FIX_V9"
    text = _strip_previous_jvm_fix(text, marker)

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

        block = f"""

// {marker}
// Final override after plugin configuration: app + plugins use JVM 17.
gradle.projectsEvaluated {{
    subprojects {{
        tasks.withType<JavaCompile>().configureEach {{
            sourceCompatibility = \"17\"
            targetCompatibility = \"17\"
        }}
        tasks.withType<KotlinCompile>().configureEach {{
            compilerOptions {{
                jvmTarget.set(JvmTarget.JVM_17)
            }}
        }}
    }}
}}
"""
    else:
        block = f"""

// {marker}
gradle.projectsEvaluated {{
    subprojects {{
        tasks.withType(JavaCompile).configureEach {{
            sourceCompatibility = \"17\"
            targetCompatibility = \"17\"
        }}
        tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile).configureEach {{
            compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }}
    }}
}}
"""

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
