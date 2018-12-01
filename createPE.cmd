@echo off

:: PEBuilder v1.0.1
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
:: Release History:
:: 1.0
:: * Initial Release
:: 1.0.1
:: * Improved instructions
::
:: Future work:
:: Create a script on the PE image that will update the DAT files
:: Add optional components
:: Investigate WiFi

set pedir=c:\winpe
set mountdir=%pedir%\mount
set iso=%pedir%\WinPE.iso
set windowsdir=%mountdir%\Windows
set ghostdir="c:\Program Files\Symantec\Ghost"
set viruscan=%homedrive%%homepath%\Desktop\vscl-w32-6.0.1-l
set mytemp=%tmp%\mypedats

rd /s /q %pedir%

call copype.cmd x86 %pedir%
dism /mount-image /imagefile:%pedir%\media\sources\boot.wim /index:1 /mountdir:%mountdir%

dism /image:%mountdir% /set-scratchspace:128

copy %ghostdir%\*32.exe %windowsdir%
copy %ghostdir%\ghostexp.exe %windowsdir%

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

dism /unmount-image /mountdir:%mountdir% /commit

makewinpemedia /iso %pedir% %iso%