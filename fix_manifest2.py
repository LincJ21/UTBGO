import sys

with open("android/app/src/main/AndroidManifest.xml", "r") as f:
    content = f.read()

content = content.replace("""        android:label="flutter_practica"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        <activity""", "        <activity")

with open("android/app/src/main/AndroidManifest.xml", "w") as f:
    f.write(content)
