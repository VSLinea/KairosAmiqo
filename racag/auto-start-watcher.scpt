#!/usr/bin/osascript
# Auto-start RACAG watcher on login
# This AppleScript runs in background without opening Terminal

do shell script "bash /Users/lyra/KairosMain/racag/start-watcher-daemon.sh > /dev/null 2>&1 &"
