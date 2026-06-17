-- screenshot-demo.applescript
-- Launches Examples/Demo/build/Demo.app, waits for it to render, captures a
-- screenshot of its frontmost window, and quits the app.
--
-- usage:  osascript scripts/screenshot-demo.applescript [output.png] [waitSeconds]

on run argv
    set outputPath to "/Users/kurtlee/Work/Mirror/CEF/Examples/Demo/build/screenshot.png"
    set waitSeconds to 5
    if (count of argv) ≥ 1 then set outputPath to item 1 of argv
    if (count of argv) ≥ 2 then set waitSeconds to (item 2 of argv) as integer

    set appPath to "/Users/kurtlee/Work/Mirror/CEF/Examples/Demo/build/Demo.app"

    -- launch fresh
    do shell script "open -F " & quoted form of appPath
    delay waitSeconds

    -- grab the frontmost window of "Demo"
    try
        tell application "System Events"
            tell process "Demo"
                set frontmost to true
                delay 0.5
                set winInfo to position of window 1 & size of window 1
                set x to item 1 of winInfo
                set y to item 2 of winInfo
                set w to item 3 of winInfo
                set h to item 4 of winInfo
            end tell
        end tell
        set rect to (x as string) & "," & (y as string) & "," & (w as string) & "," & (h as string)
        do shell script "/usr/sbin/screencapture -R " & rect & " -x " & quoted form of outputPath
    on error errMsg
        -- fall back to fullscreen capture if window info fails (e.g. permission)
        do shell script "/usr/sbin/screencapture -x " & quoted form of outputPath
    end try

    -- quit Demo so we don't leak processes
    try
        tell application "Demo" to quit
    end try
    delay 1
    do shell script "pkill -f 'Demo.app' || true"

    return outputPath
end run
