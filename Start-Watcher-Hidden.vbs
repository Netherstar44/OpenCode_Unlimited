' Script para iniciar el monitor de red en segundo plano (completamente invisible)
' Las alertas y confirmaciones aparecerán como notificaciones Toast de Windows.

Set fso = CreateObject("Scripting.FileSystemObject")
currentDir = fso.GetParentFolderName(WScript.ScriptFullName)
psScript = currentDir & "\Watch-NetworkChanges.ps1"

cmd = "cmd.exe /c """"" & currentDir & "\OpenCodeUnlimited.bat"""" --watch -Silent"
WshShell.Run cmd, 0, False

Set WshShell = Nothing
Set fso = Nothing
