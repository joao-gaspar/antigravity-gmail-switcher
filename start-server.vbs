Dim oShell, oFS, sUserHome, sDir, sLog, sErr, sLogDir

Set oShell = CreateObject("WScript.Shell")
Set oFS    = CreateObject("Scripting.FileSystemObject")

sUserHome = oShell.ExpandEnvironmentStrings("%USERPROFILE%")
sDir      = sUserHome & "\.gemini\antigravity-ide\scratch\gmail-switcher"
sLogDir   = oShell.ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\antigravity-monitor"
sLog      = sLogDir & "\server.log"
sErr      = sLogDir & "\server_err.log"

If Not oFS.FolderExists(sLogDir) Then oFS.CreateFolder(sLogDir)

' Find Python executable using FileSystemObject (no PowerShell, no shell commands)
Function FindPython()
    Dim candidates(10), i, appData, progFiles, progFiles86
    appData  = oShell.ExpandEnvironmentStrings("%LOCALAPPDATA%")
    progFiles   = oShell.ExpandEnvironmentStrings("%PROGRAMFILES%")
    progFiles86 = oShell.ExpandEnvironmentStrings("%PROGRAMFILES(X86)%")

    candidates(0)  = appData  & "\Programs\Python\Python312\python.exe"
    candidates(1)  = appData  & "\Programs\Python\Python311\python.exe"
    candidates(2)  = appData  & "\Programs\Python\Python310\python.exe"
    candidates(3)  = appData  & "\Programs\Python\Python39\python.exe"
    candidates(4)  = appData  & "\Programs\Python\Python38\python.exe"
    candidates(5)  = progFiles   & "\Python312\python.exe"
    candidates(6)  = progFiles   & "\Python311\python.exe"
    candidates(7)  = progFiles   & "\Python310\python.exe"
    candidates(8)  = progFiles86 & "\Python312\python.exe"
    candidates(9)  = progFiles86 & "\Python311\python.exe"
    candidates(10) = appData  & "\AGS\python\python.exe"

    For i = 0 To 10
        If oFS.FileExists(candidates(i)) Then
            FindPython = candidates(i)
            Exit Function
        End If
    Next
    FindPython = "python.exe"
End Function

Sub StartServer()
    Dim pyExe, cmd
    pyExe = FindPython()
    cmd = """" & pyExe & """ -u """ & sDir & "\server.py"""
    oShell.Run cmd, 0, False
End Sub

Function IsServerRunning()
    On Error Resume Next
    Dim oHTTP
    Set oHTTP = CreateObject("MSXML2.ServerXMLHTTP.6.0")
    oHTTP.setTimeouts 2000, 2000, 2000, 2000
    oHTTP.open "GET", "http://127.0.0.1:8000/api/status", False
    oHTTP.send
    IsServerRunning = (Err.Number = 0 And oHTTP.status = 200)
    On Error GoTo 0
End Function

' Initial start
StartServer()
WScript.Sleep 4000

' Watchdog loop: check every 30s and restart if needed
Do
    If Not IsServerRunning() Then
        StartServer()
        WScript.Sleep 4000
    End If
    WScript.Sleep 30000
Loop
