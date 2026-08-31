Dim oShell, sUserHome, sDir, sLogDir, sLog, sErr

Set oShell = CreateObject("WScript.Shell")

sUserHome = oShell.ExpandEnvironmentStrings("%USERPROFILE%")
sDir      = sUserHome & "\.gemini\antigravity-ide\scratch\gmail-switcher"

sLogDir   = oShell.ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\antigravity-monitor"
sLog      = sLogDir & "\server.log"
sErr      = sLogDir & "\server_err.log"

' Ensure log directory exists
If Not CreateObject("Scripting.FileSystemObject").FolderExists(sLogDir) Then
    CreateObject("Scripting.FileSystemObject").CreateFolder(sLogDir)
End If

Sub StartServer()
    ' Use PowerShell to dynamically locate python.exe and launch server.py hidden
    Dim psCmd
    psCmd = "powershell -NoProfile -WindowStyle Hidden -Command " & _
            """$py = (Get-Command python -ErrorAction SilentlyContinue).Source; " & _
            "if (-not $py) { $py = '$env:LOCALAPPDATA\Programs\Python\Python311\python.exe' }; " & _
            "Start-Process -FilePath $py " & _
            "-ArgumentList '-u server.py' " & _
            "-WorkingDirectory '" & sDir & "' " & _
            "-RedirectStandardOutput '" & sLog & "' " & _
            "-RedirectStandardError '" & sErr & "' " & _
            "-WindowStyle Hidden"""
    oShell.Run psCmd, 0, False
End Sub

Function IsServerRunning()
    On Error Resume Next
    Dim oHTTP
    Set oHTTP = CreateObject("MSXML2.ServerXMLHTTP.6.0")
    oHTTP.setTimeouts 2000, 2000, 2000, 2000
    oHTTP.open "GET", "http://localhost:8000/api/status", False
    oHTTP.send
    If Err.Number = 0 And oHTTP.status = 200 Then
        IsServerRunning = True
    Else
        IsServerRunning = False
    End If
    On Error GoTo 0
End Function

' Initial start
StartServer()
WScript.Sleep 4000

' Watchdog loop: silently check every 30 seconds and restart if needed
Do
    If Not IsServerRunning() Then
        StartServer()
        WScript.Sleep 4000
    End If
    WScript.Sleep 30000
Loop
