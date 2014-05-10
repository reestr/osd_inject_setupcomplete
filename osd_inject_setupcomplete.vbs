''' osd_inject_setupcomplete
'''
''' Injects addiitonal lines into setupcomplete.cmd for the 'Setup Windows and ConfigMgr'
''' portion of an OSD task sequence
'''

Dim strTargetDrive

''' Run function to find out which disk to use as the target
strTargetDrive = getTargetDrive()

'' Create a directory to hold the temporary script
Call createDir()
Call injectSetup()
Wscript.quit 0

 Sub createDir()
	On Error Resume Next
	'' Need to find the target drive
	strDirPath = strTargetDrive & "\temp"
	Set objFSO = CreateObject("Scripting.FileSystemObject")
	If Not objFSO.FolderExists(strDirPath) Then
		Set objFolder = objFSO.CreateFolder(strDirPath)
	End If
End Sub
  
''''''''''''''''''Sub to inject script to SetupCompleted.cmd
Sub injectSetup()
    'Write the background process script to (targetdrive)\temp\fix_setupcomplete.vbs
	strFilePath = strTargetDrive & "\temp\fix_setupcomplete.vbs"
	'Edit the following with the command/script we want to run as part of SetupComplete.cmd
	'The following is a very unexciting example to demonstrate the concept
	strSetupCompleteEntry = "start cmd /C pause"
	
	Set objFSO = CreateObject("Scripting.FileSystemObject")
	Set objFile = objfso.CreateTextFile(strFilePath, true)
''''' Script to put into file
	objFile.WriteLine "On Error Resume Next"
	objFile.WriteLine "FileName = """ & strTargetDrive & "\Windows\setup\scripts\setupcomplete.cmd"""
	objFile.WriteLine "Set objFSO = CreateObject(""Scripting.FileSystemObject"")"
	objFile.WriteLine "Do"
	objFile.WriteLine "If objFSO.FileExists(FileName) Then "
	objFile.WriteLine "Set objFile = objFSO.OpenTextFile(FileName, 1)"
	objFile.WriteLine "strContents = objFile.ReadAll"
	objFile.WriteLine "objFile.Close"
	objFile.WriteLine "strFirstLine = """ & strSetupCompleteEntry & """"
	objFile.WriteLine "strNewContents = strFirstLine & vbCrLf & strContents"
	objFile.WriteLine "Set objFile = objFSO.OpenTextFile(FileName, 2)"
	objFile.WriteLine "objFile.WriteLine strNewContents"
	objFile.WriteLine "objFile.Close"
	objFile.WriteLine "wscript.quit"
	objFile.WriteLine "End If"
	objFile.WriteLine "WScript.Sleep 100"
	objFile.WriteLine "Loop"
	objFile.WriteLine
	objFile.Close
'''''' Run script to make the change as another process
	Set wshShell = WScript.CreateObject ("WSCript.shell")
	errReturn =  wshshell.run(strFilePath, 6, false)
End Sub


''''''''''''''''''Function to Select Target OS Disk
''This does NOT use SCCM vars as these are not available at the point of install when this script runs
''Checks by volume label first (volname), if that fails we fall back checking each disk from first to 
''last for Windows\setup\scripts\setupcomplete.cmd
Function getTargetDrive()
	On Error Resume Next
	'The following volume name should be changed if it is known
	strVolName = "osdisk"
	strComputer = "."
	Set objWMIService = GetObject("winmgmts:\\" & strComputer & "\root\cimv2")
	Set colItems = objWMIService.ExecQuery _
		("Select * From Win32_LogicalDisk Where VolumeName =" & "'" & strVolName & "'")
	
	'Return the Drive letter if the volume name is correct, else try a little
	If colItems.count Then 
		getTargetDrive = colItems.ItemIndex(0).DeviceID
	Else 
		'Check each drive and return the first with SetupComplete.cmd on it
		Set colDisks = objWMIService.ExecQuery("Select * from Win32_LogicalDisk")
		Set fso = CreateObject("Scripting.FileSystemObject")
		For Each objDisk in colDisks
		 If (fso.FileExists(objdisk.deviceID & "\Windows\setup\scripts\setupcomplete.cmd")) Then
			getTargetDrive = objDisk.DeviceID
			Exit Function
		End If
		Next
		'If we don't find setupcomplete.cmd we should exit the script
		Wscript.Echo "No disks with setupcomplete.cmd on this system found"
		Wscript.quit
	End If
End Function


