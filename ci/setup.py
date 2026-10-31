import glob, os, re

m = 'android/app/src/main/AndroidManifest.xml'
s = open(m).read()
perms = '''<uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.WAKE_LOCK"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"/>
    <uses-permission android:name="android.permission.READ_MEDIA_AUDIO"/>
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS"/>
    '''
s = s.replace('<application', perms + '<application', 1)
s = re.sub(r'<application(\s)', r'<application android:usesCleartextTraffic="true"\1', s, count=1)
svc = '''
        <service android:name="com.ryanheise.audioservice.AudioService"
            android:foregroundServiceType="mediaPlayback"
            android:exported="true">
            <intent-filter>
                <action android:name="android.media.browse.MediaBrowserService"/>
            </intent-filter>
        </service>
        <receiver android:name="com.ryanheise.audioservice.MediaButtonReceiver"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MEDIA_BUTTON"/>
            </intent-filter>
        </receiver>
    '''
s = s.replace('</application>', svc + '</application>', 1)
s = re.sub(r'android:label="[^"]*"', 'android:label="Casete"', s, count=1)
assert 'com.ryanheise.audioservice.AudioService' in s, 'Servicio de audio no insertado'
open(m, 'w').write(s)

ok = False
for f in glob.glob('android/app/src/main/**/MainActivity.*', recursive=True):
    t = open(f).read()
    if f.endswith('.kt'):
        t = t.replace('import io.flutter.embedding.android.FlutterActivity',
                      'import com.ryanheise.audioservice.AudioServiceActivity')
        t = t.replace('FlutterActivity()', 'AudioServiceActivity()')
    else:
        t = t.replace('import io.flutter.embedding.android.FlutterActivity;',
                      'import com.ryanheise.audioservice.AudioServiceActivity;')
        t = t.replace('extends FlutterActivity', 'extends AudioServiceActivity')
    open(f, 'w').write(t)
    ok = 'AudioServiceActivity' in t
assert ok, 'MainActivity no pudo cambiarse'

d = 'android/app/src/main/res/drawable'
os.makedirs(d, exist_ok=True)
os.makedirs('android/app/src/main/res/raw', exist_ok=True)
play = 'M8,5v14l11,-7z'
pause = 'M6,19h4V5H6v14zm8,-14v14h4V5h-4z'
nxt = 'M6,18l8.5,-6L6,6v12zM16,6v12h2V6h-2z'
prv = 'M6,6h2v12H6zm3.5,6l8.5,6V6z'
stop = 'M6,6h12v12H6z'
ff = 'M4,18l8.5,-6L4,6v12zm9,-12v12l8.5,-6L13,6z'
rw = 'M11,18V6l-8.5,6 8.5,6zm0.5,-6l8.5,6V6l-8.5,6z'
note = 'M12,3v10.55c-0.59,-0.34 -1.27,-0.55 -2,-0.55 -2.21,0 -4,1.79 -4,4s1.79,4 4,4 4,-1.79 4,-4V7h4V3h-6z'
icons = {
    'audio_service_play_arrow': play, 'audio_service_play': play,
    'audio_service_pause': pause,
    'audio_service_skip_next': nxt, 'audio_service_skip_previous': prv,
    'audio_service_stop': stop,
    'audio_service_fast_forward': ff,
    'audio_service_fast_rewind': rw, 'audio_service_rewind': rw,
    'ic_notif': note,
}
for name, path in icons.items():
    open(f'{d}/{name}.xml', 'w').write(f'''<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="24"
    android:viewportHeight="24">
  <path
      android:fillColor="#FFFFFFFF"
      android:pathData="{path}"/>
</vector>
''')
open('android/app/src/main/res/raw/keep.xml', 'w').write('''<?xml version="1.0" encoding="utf-8"?>
<resources xmlns:tools="http://schemas.android.com/tools"
    tools:keep="@drawable/audio_service_*,@drawable/ic_notif,@mipmap/*" />
''')
print('setup OK:', len(icons), 'iconos')
