Dim oShell, sPyW, sDir, sLog, sLogDir

Set oShell = CreateObject("WScript.Shell")

sPyW   = "C:\Users\JoaoGaspar\AppData\Local\Programs\Python\Python311\pythonw.exe"
sDir   = "C:\Users\JoaoGaspar\.gemini\antigravity-ide\scratch\gmail-switcher"
sLogDir = oShell.ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\antigravity-monitor"
sLog   = sLogDir & "\server.log"

' Ensure log directory exists
If Not CreateObject("Scripting.FileSystemObject").FolderExists(sLogDir) Then
    CreateObject("Scripting.FileSystemObject").CreateFolder(sLogDir)
End If

oShell.CurrentDirectory = sDir

Sub StartServer()
    ' pythonw.exe runs without any console window — completely silent
    oShell.Run """" & sPyW & """ server.py >> """ & sLog & """ 2>&1", 0, False
End Sub

Function IsServerRunning()
    On Error Resume Next
    Dim oHTTP
    Set oHTTP = CreateObject("MSXML2.ServerXMLHTTP.6.0")
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

