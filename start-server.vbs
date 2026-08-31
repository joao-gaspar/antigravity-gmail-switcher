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
    Dim oExec, sOut
    Set oExec = oShell.Exec("powershell -NoProfile -NonInteractive -Command ""(Test-NetConnection -ComputerName localhost -Port 8000 -InformationLevel Quiet 2>$null).ToString()""")
    Do While oExec.Status = 0 : WScript.Sleep 200 : Loop
    sOut = Trim(oExec.StdOut.ReadAll())
    IsServerRunning = (LCase(sOut) = "true")
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

