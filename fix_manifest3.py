import sys

with open("android/app/src/main/AndroidManifest.xml", "r") as f:
    content = f.read()

content = content.replace("""    <application
        <activity""", """    <application>
        <activity""")

with open("android/app/src/main/AndroidManifest.xml", "w") as f:
    f.write(content)
