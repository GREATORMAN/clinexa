"""Portable tests for transformations called by the Windows installer."""
from pathlib import Path
import importlib.util
import pytest

def load_script(name):
    path=Path(__file__).resolve().parents[2]/'scripts'/f'{name}.py'
    spec=importlib.util.spec_from_file_location(name,path);module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);return module
native=load_script('configure_native_v9');preflight=load_script('preflight_install')
MANIFEST='<manifest xmlns:android="http://schemas.android.com/apk/res/android"><application android:label="Clinexa"><receiver android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" android:exported="false"/></application></manifest>'
def test_manifest_partial_setup_and_repeat():
    result=native.manifest_text(MANIFEST)
    assert 'ScheduledNotificationBootReceiver' in result
    assert result.count('android.permission.POST_NOTIFICATIONS')==1
    assert native.manifest_text(result)==result
@pytest.mark.parametrize('kotlin',[True,False])
def test_gradle_existing_dependency_missing_enabled_flag(kotlin):
    sdk='compileSdk = 34' if kotlin else 'compileSdkVersion 34'
    dependency='coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")' if kotlin else "coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'"
    source=f'android {{\n{sdk}\ncompileOptions {{\nsourceCompatibility = JavaVersion.VERSION_17\n}}\n}}\ndependencies {{\n{dependency}\n}}'
    result=native.gradle_text(source,kotlin)
    assert ('isCoreLibraryDesugaringEnabled = true' if kotlin else 'coreLibraryDesugaringEnabled true') in result
    assert result.count('com.android.tools:desugar_jdk_libs')==1 and '35' in result
    assert native.gradle_text(result,kotlin)==result

def test_native_validation_failure_changes_no_files(tmp_path):
    manifest=tmp_path/'frontend/android/app/src/main/AndroidManifest.xml';manifest.parent.mkdir(parents=True);manifest.write_text(MANIFEST)
    gradle=tmp_path/'frontend/android/app/build.gradle.kts';gradle.write_text('android { compileSdk = 34 }')
    with pytest.raises(ValueError):native.configure(tmp_path)
    assert manifest.read_text()==MANIFEST and not manifest.with_name(manifest.name+'.pre_v9').exists()

def test_preflight_missing_flutter_and_target_is_read_only(tmp_path):
    source=Path(__file__).resolve().parents[2]
    before=list(tmp_path.iterdir());errors=preflight.check(source,tmp_path,find=lambda command:None)
    assert any('Flutter' in e for e in errors) and any('Target is missing' in e for e in errors)
    assert list(tmp_path.iterdir())==before


def test_root_gradle_migrates_legacy_kotlin_options_marker():
    source = """import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

allprojects { repositories { google(); mavenCentral() } }

// CLINEXA_JVM_TARGET_FIX_V9
subprojects {
    tasks.withType<KotlinCompile>().configureEach {
        kotlinOptions {
            jvmTarget = "11"
        }
    }
}
"""
    result = native.root_gradle_text(source, True)
    assert "kotlinOptions" not in result
    assert "compilerOptions" in result
    assert "JvmTarget.JVM_17" in result
    assert native.root_gradle_text(result, True) == result


def test_root_gradle_new_kotlin_fix_is_idempotent():
    source = "allprojects { repositories { google(); mavenCentral() } }"
    result = native.root_gradle_text(source, True)
    assert result.count("CLINEXA_JVM_TARGET_FIX_V9") == 1
    assert "compilerOptions" in result
    assert native.root_gradle_text(result, True) == result


def test_root_gradle_v3_marker_upgrades_to_final_jvm17_override():
    source = """import org.gradle.api.tasks.compile.JavaCompile
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

allprojects { repositories { google(); mavenCentral() } }

// CLINEXA_JVM_TARGET_FIX_V9
subprojects {
    tasks.withType<JavaCompile>().configureEach {
        sourceCompatibility = "11"
        targetCompatibility = "11"
    }
    tasks.withType<KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(JvmTarget.JVM_11)
        }
    }
}
"""
    result = native.root_gradle_text(source, True)
    assert "gradle.projectsEvaluated" in result
    assert 'sourceCompatibility = "17"' in result
    assert 'targetCompatibility = "17"' in result
    assert "JvmTarget.JVM_17" in result
    assert "JvmTarget.JVM_11" not in result
    assert native.root_gradle_text(result, True) == result
