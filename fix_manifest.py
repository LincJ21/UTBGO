import sys

with open("android/app/src/main/AndroidManifest.xml", "r") as f:
    content = f.read()

content = content.replace("""<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
    <uses-permission android:name="android.permission.VIBRATE" />
    <uses-permission android:name="android.permission.USE_EXACT_ALARM" />
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    package="com.example.flutter_practica">
    <application
        <meta-data
            android:name="flutter_local_notifications_notification_icon"
            android:resource="@mipmap/ic_launcher" />""", """<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.example.flutter_practica">

    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
    <uses-permission android:name="android.permission.VIBRATE" />
    <uses-permission android:name="android.permission.USE_EXACT_ALARM" />
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

    <application
        android:label="flutter_practica"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        <meta-data
            android:name="flutter_local_notifications_notification_icon"
            android:resource="@mipmap/ic_launcher" />""")

with open("android/app/src/main/AndroidManifest.xml", "w") as f:
    f.write(content)
