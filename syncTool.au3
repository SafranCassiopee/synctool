#cs

    This script scynchronise to folders local or remote (in both ways)
    Copyright (C) 2015  Jean-Philippe JOUX

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#ce


#include <File.au3>
#include <Constants.au3>

Global $logPath = 'c:\temp\syncTool.log'





; parsing command line arguments
$originalDstFolder = '\\10.74.6.212\rsync'
$rsyncFilename = "C:\var\synctool\list.txt"

Global $rsyncFilename = ""
Global $originalDstFolder = ""
Global $originalSrcFolder = ""

Global $isUncSrcFolder = False
Global $isUncDstFolder = False
Global $srcDriveLetter = ""
Global $dstDriveLetter = ""

_log("Starting Synchronisation Tool")

; Function to call when program exit (for all use cases)
OnAutoItExitRegister("OnAutoItExit")

$originalSrcFolder = ""
$originalDstFolder = ""
$rsyncFilename = ""

; Reading command line args
ReadCmdLineParams()

; Mounting drives if needed
if _isUncDrive($originalDstFolder) Then
   $dstDriveLetter = mountDrive($originalDstFolder)
   $isUncDstFolder = True

Else
   $dstDriveLetter = $originalDstFolder
EndIf

if _isUncDrive($originalSrcFolder) Then
   $srcDriveLetter = mountDrive($originalSrcFolder)
   $isUncSrcFolder = True

Else
   $srcDriveLetter = $originalSrcFolder
EndIf



;Synchronisation
; Master -> Filiale
rsync($srcDriveLetter, $dstDriveLetter, $rsyncFilename)

; Filiale -> Master
rsync($dstDriveLetter, $srcDriveLetter, $rsyncFilename)

exit(0)

Func rsync($src, $dest, $file)
   _log("Starting synchronisation from " & $src & " to " & $dest)

   $rsyncCmd = @ScriptDir & "\rsync\x86\rsync.exe"
   $rsyncArgs = "-vrh --append --size-only --log-file="&win2cygdrv($logPath)&" --chmod=ugo=rwX --files-from=""" & win2cygdrv($rsyncFilename) & """"
   $rsyncSrc = """" & win2cygdrv($src) & "/"""
   $rsyncDest = """" & win2cygdrv($dest) & """"

   $cmd = $rsyncCmd &  " " & $rsyncArgs & " " & $rsyncSrc & " " & $rsyncDest
   ; ConsoleWrite ( "rsync cmd: " & $cmd & @CRLF)

   Local $retCode = RunWait($cmd, "", @SW_HIDE, $STDERR_CHILD + $STDOUT_CHILD)

   If $retCode Then
	  $msg = ""
	  Switch $retCode
		 case 0
			$msg = "Success"
		 case 1
			$msg = "Syntax or usage error"
		 case 2
			$msg = "Protocol incompatibility"
		 case 3
			$msg = "Errors selecting input/output files, dirs"
		 case 4
			$msg = "Requested  action not supported: an attempt was made to manipulate 64-bit files on a platform that cannot support them; or an option was specified that is supported by the client and not by the server."
		 case 5
			$msg = "Error starting client-server protocol"
		 case 6
			$msg = "Daemon unable to append to log-file"
		 case 10
			$msg = "Error in socket I/O"
		 case 11
			$msg = "Error in file I/O"
		 case 12
			$msg = "Error in rsync protocol data stream"
		 case 13
			$msg = "Errors with program diagnostics"
		 case 14
			$msg = "Error in IPC code"
		 case 20
			$msg = "Received SIGUSR1 or SIGINT"
		 case 21
			$msg = "Some error returned by waitpid()"
		 case 22
			$msg = "Error allocating core memory buffers"
		 case 23
			$msg = "Partial transfer due to error"
		 case 24
			$msg = "Partial transfer due to vanished source files"
		 case 25
			$msg = "The --max-delete limit stopped deletions"
		 case 30
			$msg = "Timeout in data send/receive"
		 case 35
			$msg = "Timeout waiting for daemon connection"
	  EndSwitch

	  Switch $retCode
		 case 23
			_log("Ignoring previous errors (Normal - Synchronisation in progress)")
			return 0
		 case Else
			_log("Rsync return code: " & $retCode & " (" & $msg & ")")
			exit ($retCode+50)
	  EndSwitch
   EndIf

EndFunc

;transform a windows path to a cygdrive path
Func win2cygdrv($path)
   Local $pathArray = StringSplit ($path, ":")
   local $cygPath = "/cygdrive/" & StringLower ($pathArray[1]) & StringReplace ($pathArray[2], "\", "/")
   return $cygPath
EndFunc

Func mountDrive($url)
   ; *: =use the fisrt available device
   _log("Mounting drive " & $url)
   $ret = DriveMapAdd("*", $url, 0)
   $errorCode = @error
   $extendedCode = @extended

   If $ret Then
	  $driveLetter = $ret
	  _log("Using drive letter " & $ret)
   Else
	  $detail =  ""

	  Switch $errorCode
		 case 1
			$detail = "Undefined / Other error. Windows error: " & $extendedCode
		 case 2
			$detail = "Access to the remote share was denied"
		 case 3
			$detail = "The device is already assigned"
		 case 4
			$detail = "Invalid device name"
		 case 5
			$detail = "Invalid remote share"
		 case 6
			$detail = "Invalid password"
	  EndSwitch

	  _log("Error when mounting " & $url & ": " & $detail)
	  exit(10+$errorCode)

   EndIf

   return $ret
EndFunc

Func uMountDrive($drive)
   _log ("Unmounting drive " & $drive)
   $ret = DriveMapDel ( $drive )
   if $ret == 0 then
	  log("Unable to umount drive")
	  exit(20+$ret)
   endif
EndFunc


Func ReadCmdLineParams() 	;Read in the optional switch set in the users profile and set a variable - used in case selection
   ; _log ("Parsing commandline args: " & $CmdLineRaw)
   ; Loop through every arguement
   ; $cmdLine[0] is an integer that is eqaul to the total number of arguements that we passwed to the command line
   for $i = 1 to $cmdLine[0]
	  Select
		 ;;If the arguement equal -h (help)
		 case $CmdLine[$i] = "-h"
			 ;check for missing argument
			if $i == $CmdLine[0] Then
			   cmdLineHelpMsg()
			EndIf

			;Make sure the next argument is not another paramter
			if StringLeft($cmdline[$i+1], 1) == "-" Then
			   cmdLineHelpMsg()
			EndIf

		 ;;If the arguement equal  -f (file list to sync)
		 case $CmdLine[$i] = "-f"

			;check for missing arguement
			if $i == $CmdLine[0] Then
			   cmdLineHelpMsg()
			EndIf

			;Make sure the next argument is not another paramter
			if StringLeft($cmdline[$i+1], 1) == "-" Then
			   cmdLineHelpMsg()
			Else
			   ;;Stip white space from the begining and end of the input
			   ;;Not alway nessary let it in just in case
			   $rsyncFilename= StringStripWS($CmdLine[$i + 1], 3)
			EndIf

		 ;;If the arguement equal  -d (destination folder)
		 case $CmdLine[$i] = "-d"

			;check for missing arguement
			if $i == $CmdLine[0] Then
			   cmdLineHelpMsg()
			EndIf

			;Make sure the next argument is not another paramter
			if StringLeft($cmdline[$i+1], 1) == "-" Then
			   cmdLineHelpMsg()
			Else
			   ;;Stip white space from the begining and end of the input
			   ;;Not alway nessary let it in just in case
			   $originalDstFolder = StringRegExpReplace(StringStripWS($CmdLine[$i + 1], 3), '[\\/]+$', '')
			EndIf

		 ;;If the arguement equal  -s (source folder)
		 case $CmdLine[$i] = "-s"

			;check for missing arguement
			if $i == $CmdLine[0] Then
			   cmdLineHelpMsg()
			EndIf

			;Make sure the next argument is not another paramter
			if StringLeft($cmdline[$i+1], 1) == "-" Then
			   cmdLineHelpMsg()
			Else
			   ;;Stip white space from the begining and end of the input
			   ;;Not alway nessary let it in just in case
			   $originalSrcFolder = StringRegExpReplace(StringStripWS($CmdLine[$i + 1], 3), '[\\/]+$', '')
			EndIf

	  EndSelect
   Next

   If $rsyncFilename == "" or $originalDstFolder == "" or $originalSrcFolder = "" or $rsyncFilename == "" Then
	  cmdLineHelpMsg()
   EndIf

EndFunc

Func cmdLineHelpMsg()
	ConsoleWrite(@LF & "syncTool Copyright (C) 2015 Jean-Philippe JOUX" & @LF & _
			"This program comes with ABSOLUTELY NO WARRANTY." & @LF & _
			"This is free software, and you are welcome to redistribute it under certain conditions; " & @LF & _
			"Read LICENCE.txt file for for details." & @LF & @LF & _
				  "Syntax:" & @tab & 'syncTool.exe [options]' & @LF & @LF & _
				  "Required Options:" & @LF & _
				  "-s [source folder] "& @tab & " Full path to the local folder. Ex: \\192.168.5.2\data or C:\test\data" & @LF & _
				  "-d [destination folder]" & @tab & " Full path to the destination folder. Ex: \\192.168.5.1\data or C:\data" & @LF & _
				  "-f [file]" & @tab & @tab & " Path to the file list to synchronize. Ex: c:\temp\xxx_files.txt" & @LF )
   Exit 1
EndFunc

;Test if the path is an UNC or a local path
Func _isUncDrive($path)
   Return (StringCompare(StringLeft ( $path, 2 ), "\\") == 0)
EndFunc

Func _isFolderWritable($path)

   $ret = False
   $tst_file = $path & "\writable_test_file.txt"

   ; testing write acces on path
   If Not _FileCreate($tst_file) Then
	  _log("[ERROR] - Unable to write in " & $path)
   Else
	  FileDelete ($tst_file)
	  $ret = True
   EndIf

   return $ret
EndFunc


Func _log($msg)
   ; logs the message in the configured log file
   _FileWriteLog ( $logPath, $msg )
EndFunc   ;

Func onAutoItExit()
   ; Unmounting mounted drives
   if $isUncDstFolder Then
	  uMountDrive($dstDriveLetter)
   EndIf

   if $isUncSrcFolder Then
	  uMountDrive($srcDriveLetter)
   EndIf

   _log("Stopping Synchronisation Tool")

EndFunc   ;
