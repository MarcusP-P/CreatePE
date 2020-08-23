@echo off

:: PEBuilder v4.0.3
:: (C) Copyright Marcus Pallinger 2013-2020
::
:: Designed for use with Windows 10 1803 or later
:: To be used with the latest Windows Assessment and Deployment Kit (and 
:: Windows PE add-on), but may work with earlier versions.
:: ADK versions 1809 and later have split Windows PE into a seperate
:: add on.
:: The Windows 10 2004 ADK can be found at 
:: https://go.microsoft.com/fwlink/?linkid=2120254
:: And the Windows PE add-on can be found at:
:: https://go.microsoft.com/fwlink/?linkid=2120253
::
:: All versions of the ADK can be found at
:: https://docs.microsoft.com/en-us/windows-hardware/get-started/adk-install
::
:: It assumes the Symantec Ghost Solution Suite files are in the "GSS" folder
:: The following files should be in that folder, but they aren't actually 
:: checked:
:: gdisk32.exe
:: ghGonfig32.exe
:: DeployAnywhere32.exe/ghDplyAW32.exe
:: ghost32.exe
:: ghostexp32.exe
:: gdisk64.exe
:: ghGonfig64.exe
:: DeployAnywhere64.exe/ghDplyAW64.exe
:: ghost64.exe
:: ghostexp64.exe
:: NOTE: Some 32 bit files don't include the 32 at the end of the filename. It
:: needs to be added manually
::
:: If you want to use Windows Defender Offline, you will need to match the 
:: bitness of the version of Windows to scan.
::
:: You will need a Drivers direcory on the desktop, even if it is empty.
:: Copy an drivers into this directory.
::
:: To run this script, Click Start, and type deployment. Right-click Deployment 
:: and Imaging Tools Environment and then select Run as administrator. Then run 
:: this script in that command window.
::
:: If you want to create a USB drive, prepare it according to the instructions
:: at:
:: https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/winpe--use-a-single-usb-key-for-winpe-and-a-wim-file---wim
:: Windows may not allow you to create two partitions on a USB drive. If the 
:: above instructions fail, try the following:
:: diskpart
:: list disk
:: select <disk number>
:: clean
:: rem === Create the Windows PE partition. ===
:: create partition primary
:: format quick fs=fat32 label="Windows PE"
:: assign letter=P
:: active
::
:: To get usage information, run without paramaters
::
:: Release History:
:: 1.0   (22/02/2013)
:: * Initial Release
:: 1.0.1 (22/02/2013)
:: * Improved instructions
:: 2.0   (07/11/2013)
:: * Allow creation of an image on an x64 system
:: * Allow the cration of 32 or 64 bit image
:: * Change to the current directory once we finish
:: 2.1   (08/11/2013)
:: * Allow the user to create a USB disk isntead of an ISO
:: 2.1.1 (08/11/2013)
:: * Mcafee have removed the SDAT from the FTP site. Use the xdat file.
:: 2.1.2 (26/11/2013)
:: * Fix ISO creation
:: 3.0   (09/10/2015)
:: * Ghost files now need to be in a GSS directory on the desktop. This allows
::   us to easily use the new 12.0.x versions from Symantec Support
:: * Install user supplied drivers
:: 3.0.1 (09/10/2015)
:: * Allow for spaces in home directory and PE directory
:: * Add descriptions of what we are doing
:: 4.0   (06/11/2018)
:: * Add Windows Defender Offline scanning
:: * Remove Mcafee Virus Scan
:: * Speed up of unmount if we havn't unmounted at the end of the previous run
:: 4.0.1 (08/11/2018
:: * Wrap comments to 80 characters, where possible
:: * Add Copyright
:: 4.0.2 (08/11/2018)
:: * Add release dates to changelog
:: 4.0.3 
:: * Update ADK section of the notes
:: * Display commands to run defender
::
:: Future work:
:: Check for existance of Drivers directory before trying to install them
:: Create a script on the PE image that will update the defender data files
:: Add optional components
:: Investigate WiFi
:: Allow for building of a UEFI 64 bit version
:: Investigate WoW64 on the PE image
:: Check for Ghost directory, and abort if they aren't there
:: Make the script more modular

:: Remmeber the current directory
set InitialLocation=%CD%

:: Symantec Ghost installs as an x86 application. We need to find the right 
:: Program Files directory

if "%PROCESSOR_ARCHITECTURE%"=="AMD64" goto amd64host
if "%PROCESSOR_ARCHITECTURE%"=="x86" goto x86host
echo Unable to create a PE Image on a %PROCESSOR_ARCHITECTURE% system
goto end

:amd64host
set progdir=%ProgramFiles(x86)%
echo Generating on a 64 bit host
goto endHostSpecific

:x86host
set progdir=%ProgramFiles%
echo Generating on a 32 bit host
goto endHostSpecific

:endHostSpecific

:: Select which architecture to build for
if "%1"=="" goto usage

if "%1"=="x86" goto x86image
if "%1"=="amd64" goto amd64image

goto usage

:: Windows Defender Offline URLs are different for the 32 and 64 bit version.
:: the image URLS are from 
:: https://www.verboon.info/2012/01/how-the-windows-defender-offline-beta-tool-works/
:: the definition URLs are from https://www.microsoft.com/en-us/wdsi/definitions

:amd64image
set bits=64
set archFlag=amd64
:: Windows Defender Offline Image and definitions
set wdoimageurl=http://go.microsoft.com/fwlink/?LinkId=232569
set wdodefinitionurl="https://go.microsoft.com/fwlink/?LinkID=121721&arch=x64"
set wdoDefinitionFile=mpam-feX64.exe

goto endDestArchitecture

:x86image
set bits=32
set archFlag=x86
:: Windows Defender Offline Image and definitions
set wdoimageurl=http://go.microsoft.com/fwlink/?LinkId=232568
set wdodefinitionurl="https://go.microsoft.com/fwlink/?LinkID=121721&arch=x86"
set wdoDefinitionFile=mpam-fe.exe

goto endDestArchitecture

:endDestArchitecture

set usb=no

if "%2"=="" goto nousb
if not "%2"=="/usb" goto usage

if "%3"=="" goto usage

set usb=yes
set drive=%3
set buildType=/ufd

goto endOptions

:nousb
set usb=no
set buildType=/iso
goto endOptions

:usage

echo Usage:
echo createPE architecture [/usb drive]
echo Options:
echo   architecture: must be either x86 or amd64. It selects for which 
echo     architecture to build the ISO.
echo   /usb: Create a USB stick rather than an iso image.
echo   drive: The drive letter to use when creating a USB disk 

goto end

:endOptions

set pedir=c:\winpe
set mountdir=%pedir%\mount
set windowsdir=%mountdir%\Windows
set ghostdir=%homedrive%%homepath%\Desktop\gss
set drivers=%homedrive%%homepath%\Desktop\drivers
set mytemp=%tmp%\createPE

:: architecture independent WDO config
set wdoImageFile=ImagePackage.exe
set wdoExtractDir=%mytemp%\wdoExtract
set wdoMountDir=%pedir%\wdo


if "%usb%"=="no" set iso=%pedir%\WinPE%bits%.iso
if "%usb%"=="yes" set iso=%drive%

echo Force an unmount before we begin
dism /unmount-image /mountdir:"%mountdir%" /discard

echo Force unmount of Windows Defender Online image 
dism /unmount-image /mountdir:"%wdoMountDir%" /discard

echo Remove old PE directory
rd /s /q "%pedir%"

echo Remove old temp directory
rd /s /q "%mytemp%"

echo creating temp directory
mkdir "%mytemp%"
echo Copying PE files
call copype.cmd %archflag% "%pedir%"

echo Mounting image
dism /mount-image /imagefile:"%pedir%\media\sources\boot.wim" /index:1 /mountdir:"%mountdir%"

echo setting Scratch Space
dism /image:"%mountdir%" /set-scratchspace:128

:: Install drivers
echo Installing Drivers
for %%d IN ("%drivers%"\*.inf) do dism /Add-Driver /Image:"%mountdir%" /Driver:"%%d"
dism /Get-Drivers /Image:"%mountdir%"

::
echo Copying Ghost
copy "%ghostdir%\*%bits%.exe" "%windowsdir%"


:: Get the WDO Image
echo Getting Windows Defener Online image
curl -L -o "%mytemp%\%wdoImageFile%" "%wdoimageurl%"

echo Extracting Windows Defener Online Image
"%mytemp%\%wdoImageFile%" /x:"%wdoExtractDir%" /q

echo Mounting Windows Defender Online image
mkdir "%wdoMountDir%"

dism /mount-image /ReadOnly /imagefile:"%wdoExtractDir%\sources\boot.wim" /index:1 /mountdir:"%wdoMountDir%"

echo Copying Windows Defender Online files
xcopy /S /E /I "%wdoMountDir%\Program Files\Microsoft Security Client" "%mountDir%\Program Files\Microsoft Security Client"

echo Unmounting Windows Defender Online image
dism /unmount-image /mountdir:"%wdoMountDir%" /discard

echo Removing Windows Defender Online mountpoint
rd /s /q "%wdoMountDir%"

echo Downloading latest definitions
curl -L -o "%mountDir%\%wdoDefinitionFile%" %wdodefinitionurl%

(
	echo @echo off
	echo "X:\Program Files\Microsoft Security Client\OfflineScannerShell"
) > "%windowsdir%"\defender.bat

echo @echo To run Windows Defender Offline, run defender.bat >> "%windowsdir%"\system32\startnet.cmd
	
:: Finalise
echo Unmounting image
dism /unmount-image /mountdir:"%mountdir%" /commit

echo Making media
call makewinpemedia %buildType% "%pedir%" "%iso%"
if Not "%usb%"=="no" goto end
echo Copying ISO
copy "%iso%" "%InitialLocation%"
:end
cd "%InitialLocation%"
