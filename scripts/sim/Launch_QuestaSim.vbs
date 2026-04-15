Dim sh : Set sh = CreateObject("WScript.Shell")
Dim fso : Set fso = CreateObject("Scripting.FileSystemObject")

' Derive paths relative to this script's location
Dim scriptDir : scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
Dim repoRoot  : repoRoot  = fso.GetParentFolderName(scriptDir)

sh.CurrentDirectory = scriptDir

' Search for vsim.exe: check PATH first, then common Questa install roots
Dim vsim : vsim = ""

On Error Resume Next
vsim = sh.Exec("where vsim.exe").StdOut.ReadLine()
On Error GoTo 0

If vsim = "" Then
    ' Walk common install patterns: C:\<vendor>\<version>\questa*\win64\vsim.exe
    Dim drives : drives = Array("C:", "D:")
    Dim vendors : vendors = Array("intelFPGA", "intelFPGA_lite", "altera", "questaintel")
    Dim d, v, yr, qDir, candidate
    For Each d In drives
        For Each v In vendors
            Dim instRoot : instRoot = d & "\" & v
            If fso.FolderExists(instRoot) Then
                Dim vFolder : Set vFolder = fso.GetFolder(instRoot)
                For Each yr In vFolder.SubFolders
                    For Each qDir In yr.SubFolders
                        If LCase(Left(qDir.Name, 6)) = "questa" Then
                            candidate = qDir.Path & "\win64\vsim.exe"
                            If fso.FileExists(candidate) Then
                                vsim = candidate
                            End If
                        End If
                    Next
                    If vsim <> "" Then Exit For
                Next
            End If
            If vsim <> "" Then Exit For
        Next
        If vsim <> "" Then Exit For
    Next
End If

If vsim = "" Then
    MsgBox "vsim.exe not found on PATH or in common install locations." & vbCrLf & _
           "Add Questa's win64\ directory to your PATH and retry.", vbCritical, "Launch QuestaSim"
    WScript.Quit 1
End If

sh.Run """" & vsim & """ -gui", 0
