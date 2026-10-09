"""Idempotent Android reminder setup; preserves package and signing settings."""
from pathlib import Path
import re
import xml.etree.ElementTree as ET

def manifest_text(text):
    for permission in ['POST_NOTIFICATIONS','RECEIVE_BOOT_COMPLETED']:
        if 'android.permission.'+permission not in text:
            text=text.replace('<application',f'<uses-permission android:name="android.permission.{permission}" />\n    <application',1)
    if 'android:allowBackup' not in text:text=text.replace('<application','<application android:allowBackup="false"',1)
    prefix='com.dexterous.flutterlocalnotifications.'
    if prefix+'ScheduledNotificationReceiver' not in text:
        text=text.replace('</application>',f'<receiver android:exported="false" android:name="{prefix}ScheduledNotificationReceiver" />\n</application>')
    if prefix+'ScheduledNotificationBootReceiver' not in text:
        text=text.replace('</application>',f'<receiver android:exported="false" android:name="{prefix}ScheduledNotificationBootReceiver"><intent-filter><action android:name="android.intent.action.BOOT_COMPLETED"/><action android:name="android.intent.action.MY_PACKAGE_REPLACED"/></intent-filter></receiver>\n</application>')
    ET.fromstring(text)
    return text

def gradle_text(text,kotlin):
    flag='isCoreLibraryDesugaringEnabled = true' if kotlin else 'coreLibraryDesugaringEnabled true'
    pattern=r'isCoreLibraryDesugaringEnabled\s*=\s*(?:true|false)' if kotlin else r'coreLibraryDesugaringEnabled\s*(?:=\s*)?(?:true|false)'
    if re.search(pattern,text):text=re.sub(pattern,flag,text)
    else:
        if 'compileOptions {' not in text:raise ValueError('No compileOptions block found; configure desugaring manually before retrying.')
        text=text.replace('compileOptions {','compileOptions {\n        '+flag,1)
    if not re.search(r'\bcoreLibraryDesugaring\s*[\(\s][\s\'\"]*com.android.tools:desugar_jdk_libs',text):
        dependency='coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")' if kotlin else "coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'"
        text+='\ndependencies {\n    '+dependency+'\n}\n'
    if kotlin:
        text=re.sub(r'compileSdk\s*=\s*flutter.compileSdkVersion','compileSdk = maxOf(35, flutter.compileSdkVersion)',text)
        text=re.sub(r'compileSdk\s*=\s*(\d+)',lambda m:'compileSdk = '+str(max(35,int(m.group(1)))),text)
    else:
        text=re.sub(r'compileSdk(?:Version)?\s+(?:=\s*)?flutter.compileSdkVersion','compileSdkVersion Math.max(35, flutter.compileSdkVersion)',text)
        text=re.sub(r'compileSdk(?:Version)?\s+(?:=\s*)?(\d+)',lambda m:'compileSdkVersion '+str(max(35,int(m.group(1)))),text)
    return text

def configure(root):
    changes=[];manifest=root/'frontend/android/app/src/main/AndroidManifest.xml'
    if manifest.exists():changes.append((manifest,manifest_text(manifest.read_text(encoding='utf-8-sig'))))
    for name in ['build.gradle.kts','build.gradle']:
        path=root/'frontend/android/app'/name
        if path.exists():changes.append((path,gradle_text(path.read_text(),name.endswith('.kts'))))
    # Validate every transformation before changing the native project.
    for path,text in changes:
        backup=path.with_name(path.name+'.pre_v9')
        if not backup.exists():backup.write_bytes(path.read_bytes())
        path.write_text(text,encoding='utf-8')
    print('Android reminder setup configured. iOS still requires its documented platform steps.')
if __name__=='__main__':configure(Path(__file__).resolve().parent.parent)
