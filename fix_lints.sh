#!/bin/bash
sed -i 's/withOpacity(\([0-9.]*\))/withValues(alpha: \1)/g' lib/app/view/*.dart
sed -i 's/if (response.statusCode == 200) {/if (!mounted) return; if (response.statusCode == 200) {/g' lib/app/view/login_screen.dart lib/app/view/upload_video_screen.dart
