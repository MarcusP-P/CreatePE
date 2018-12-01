@echo off

:: PEBuilder v2.0
:: Designed for use with the Windows 8 Assessment and Deployment Kit, but may work
:: with earlier versions.
:: The ADK can be found at http://www.microsoft.com/en-us/download/details.aspx?id=30652
::
:: It assumes Symantec Ghost Solution Suite is installed in the default directory.
:: It also assumes that the commandline Virus Scan is unzipped in the desktop
:: If you have a licence, Command line virus scan can be downloaded from 
:: http://www.mcafeeasap.com/downloads/CLS/vscl-w32-6.0.1-l.zip
:: It will install the latest Mcafee SuperDat.
::
:: Virus scan may say "mcscan32.dll has failed its integrity check" if you aren't
:: connected to the network. Start scan with the /NC switch.
:: for mroe info: https://kc.mcafee.com/corporate/index?page=content&id=kb68314
::
:: To run this script, Click Start, and type deployment. Right-click Deployment 
:: and Imaging Tools Environment and then select Run as administrator. Then run 
:: this script in that command window.
::
:: Usage:
:: createPE architecture
:: Options:
::   architecture must be either x86 or amd64. It selects for which architecture to build
::   the ISO.
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
::
:: Future work:
:: Create a script on the PE image that will update the DAT files
:: Add optional components
:: Investigate WiFi
:: Allow for building of a UEFI 64 bit version
:: Investigate WoW64 on the PE image
:: Check for Ghost and Mcafee directories, and abort if they aren't there

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
goto endHostSpecific

:x86host
set progdir=%ProgramFiles%
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

:usage

echo Usage:
echo createPE architecture
echo Options:
echo   architecture must be either x86 or amd64. It selects for which architecture to build
echo   the ISO.

goto end


:endDestArchitecture


set pedir=c:\winpe
set mountdir=%pedir%\mount
set iso=%pedir%\WinPE%bits%.iso
set windowsdir=%mountdir%\Windows
set ghostdir="%progdir%\Symantec\Ghost"
set viruscan=%homedrive%%homepath%\Desktop\vscl-w32-6.0.1-l
set mytemp=%tmp%\mypedats

rd /s /q %pedir%

call copype.cmd %archflag% %pedir%
dism /mount-image /imagefile:%pedir%\media\sources\boot.wim /index:1 /mountdir:%mountdir%

dism /image:%mountdir% /set-scratchspace:128

copy %ghostdir%\*%bits%.exe %windowsdir%
if not "%bits%"=="32" goto endGhostArchSpecific
copy %ghostdir%\ghostexp.exe %windowsdir%
:endGhostArchSpecific

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

set superdat=sdat%currentdat%.exe

del getdat.scr

> getdat.scr ECHO ftp
>>getdat.scr ECHO @
>>getdat.scr ECHO bin
>>getdat.scr ECHO cd virusdefs
>>getdat.scr ECHO cd 4.x
>>getdat.scr ECHO get %superdat%
>>getdat.scr ECHO quit

ftp -s:getdat.scr ftp.mcafee.com

start /wait %superdat% /engineall /silent

copy *.dll %windowsdir%
copy *.dat %windowsdir%

:endMcafee

dism /unmount-image /mountdir:%mountdir% /commit

call makewinpemedia /iso %pedir% %iso%
copy %iso% %InitialLocation%
:end
cd %InitialLocation%