Dim oShell, oFS, sPyExe, sDir, sCmd, oExec, sNetstat

Set oShell = CreateObject("WScript.Shell")
Set oFS    = CreateObject("Scripting.FileSystemObject")

sPyExe = "C:\Users\JoaoGaspar\AppData\Local\Programs\Python\Python311\python.exe"
sDir   = "C:\Users\JoaoGaspar\.gemini\antigravity-ide\scratch\gmail-switcher"
oShell.CurrentDirectory = sDir

Sub StartServer()
    oShell.Run """" & sPyExe & """ server.py", 0, False
End Sub

Function IsServerRunning()
    Dim oExec2, sOut
    Set oExec2 = oShell.Exec("powershell -NoProfile -NonInteractive -Command ""(Test-NetConnection -ComputerName localhost -Port 8000 -InformationLevel Quiet 2>$null).ToString()""")
    Do While oExec2.Status = 0 : WScript.Sleep 200 : Loop
    sOut = Trim(oExec2.StdOut.ReadAll())
    IsServerRunning = (LCase(sOut) = "true")
End Function

' Initial start
StartServer()
WScript.Sleep 3000

' Watchdog loop: check every 30 seconds
Do
    If Not IsServerRunning() Then
        StartServer()
        WScript.Sleep 3000
    End If
    WScript.Sleep 30000
Loop
