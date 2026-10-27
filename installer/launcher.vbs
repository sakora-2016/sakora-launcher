Option Explicit
Dim sh, fso, dir, link, cmd
If WScript.Arguments.Count < 1 Then WScript.Quit 1
link = WScript.Arguments(0)
If LCase(Left(link, 7)) <> "sakora:" And LCase(Left(link, 14)) <> "sakora-studio:" Then WScript.Quit 1
If InStr(link, Chr(34)) > 0 Then WScript.Quit 1
Set sh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
dir = fso.GetParentFolderName(WScript.ScriptFullName)
cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File " & Chr(34) & dir & "\launcher.ps1" & Chr(34) & " " & Chr(34) & link & Chr(34)
sh.Run cmd, 0, False
