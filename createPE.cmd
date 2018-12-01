@echo off

:: PEBuilder v3.0
:: Designed for use with the Windows 8 Assessment and Deployment Kit,
:: but may work with earlier versions.
:: The ADK can be found at 
:: http://www.microsoft.com/en-us/download/details.aspx?id=30652
::
:: It assumes the Symantec Ghost Solution Suite files are in the "GSS" folder
:: The following files should be in that folder, but they aren't actually checked:
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
:: It also assumes that the commandline Virus Scan is unzipped
:: in the desktop. If you have a licence, Command line virus scan can be 
:: downloaded from 
:: http://www.mcafeeasap.com/downloads/CLS/vscl-w32-6.0.1-l.zip
:: It will install the latest Mcafee SuperDat.
::
:: You will need a Drivers direcory on the desktop, even if it is empty.
:: Copy an drivers into this directory.
::
:: Virus scan may say "mcscan32.dll has failed its integrity check" if you 
:: aren't connected to the network. Start scan with the /NC switch.
:: for mroe info: https://kc.mcafee.com/corporate/index?page=content&id=kb68314
::
:: To run this script, Click Start, and type deployment. Right-click Deployment 
:: and Imaging Tools Environment and then select Run as administrator. Then run 
:: this script in that command window.
::
:: If you want to create a USB drive, prepare it according to the instructions
:: at:
:: http://technet.microsoft.com/en-us/library/hh825045.aspx
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
:: 1.0
:: * Initial Release
:: 1.0.1
:: * Improved instructions
:: 2.0
:: * Allow creation of an image on an x64 system
:: * Allow the cration of 32 or 64 bit image
:: * Change to the current directory once we finish
:: 2.1
:: * Allow the user to create a USB disk isntead of an ISO
:: 2.1.1
:: * Mcafee have removed the SDAT from the FTP site. Use the xdat file.
:: 2.1.2
:: * Fix ISO creation
:: 3.0
:: * Ghost files now need to be in a GSS directory on the desktop. This allows
::   us to easily use the new 12.0.x versions from Symantec Support
:: * Install user supplied drivers
::
:: Future work:
:: Check for existance of Drivers directory before trying to install them
:: Create a script on the PE image that will update the DAT files
:: Add optional components
:: Investigate WiFi
:: Allow for building of a UEFI 64 bit version
:: Investigate WoW64 on the PE image
:: Check for Ghost and Mcafee directories, and abort if they aren't there
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

:amd64image
set bits=64
set mcafee=no
set archFlag=amd64
goto endDestArchitecture

:x86image
set bits=32
set mcafee=yes
set archFlag=x86
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
set viruscan=%homedrive%%homepath%\Desktop\vscl-w32-6.0.1-l
set drivers=%homedrive%%homepath%\Desktop\drivers
set mytemp=%tmp%\mypedats

if "%usb%"=="no" set iso=%pedir%\WinPE%bits%.iso
if "%usb%"=="yes" set iso=%drive%

rd /s /q %pedir%

call copype.cmd %archflag% %pedir%
dism /mount-image /imagefile:%pedir%\media\sources\boot.wim /index:1 /mountdir:%mountdir%

dism /image:%mountdir% /set-scratchspace:128

:: Install drivers
for %%d IN (%drivers%\*.inf) do dism /Add-Driver /Image:"%mountdir%" /Driver:%%d
dism /Get-Drivers /Image:"%mountdir%

copy %ghostdir%\*%bits%.exe %windowsdir%

if NOT "%mcafee%"=="yes" goto endMcafee
copy %viruscan%\*.exe %windowsdir%
copy %viruscan%\*.dat %windowsdir%
copy %viruscan%\*.dll %windowsdir%

rd /s /q %mytemp%
mkdir %mytemp%
cd %mytemp%

del /q getlist.scr

> getlist.scr ECHO ftp
>>getlist.scr ECHO @
>>getlist.scr ECHO cd commonupdater2
>>getlist.scr ECHO cd current
>>getlist.scr ECHO cd vscandat1000
>>getlist.scr ECHO cd dat
>>getlist.scr ECHO cd 0000
>>getlist.scr ECHO get avvdat.ini
>>getlist.scr ECHO quit

ftp -s:getlist.scr ftp.mcafee.com

for /f "usebackq delims== tokens=1,2" %%m in (`find /i "DATVersion" avvdat.ini`) do set currentdat=%%n

::set superdat=sdat%currentdat%.exe
set superdat=%currentdat%xdat.exe

del getdat.scr

> getdat.scr ECHO ftp
>>getdat.scr ECHO @
>>getdat.scr ECHO bin
>>getdat.scr ECHO cd virusdefs
>>getdat.scr ECHO cd 4.x
>>getdat.scr ECHO get %superdat%
>>getdat.scr ECHO quit

ftp -s:getdat.scr ftp.mcafee.com

:: start /wait %superdat% /engineall /silent
start /wait %superdat% /engineall /silent /e .
pause

copy *.dll %windowsdir%
copy *.dat %windowsdir%

:endMcafee

dism /unmount-image /mountdir:%mountdir% /commit

call makewinpemedia %buildType% %pedir% %iso%
if "%usb%"=="no" copy %iso% %InitialLocation%
:end
cd %InitialLocation%
