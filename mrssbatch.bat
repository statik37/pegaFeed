@ECHO OFF
SETLOCAL
rem MRSS Batch Generator
rem --------------------
rem Generates an MRSS feed XML file named Mrss.xml in the current from the media files in the current directory.
rem v3.5 2022/02/23 BrightSign - Brandon
rem	 - Use in order of availability: PowerShell.exe WMIC.exe, otherwise fall back to %random% for GUID
rem	 - WMIC is being deprecated by Microsoft, but newer Windows should have PowerShell
rem	 - Bugfix: Fix unescaped parentheses in echo statements
rem v3.4 2020/02/21 BrightSign - Brandon
rem	 - Remove automatic addition of trailling slash for Base URL didn't work as it requires delayed expansion - removed function, changed to error state
rem	 - Add leading 0 to single-digital day/month/hour/minute/second for timestamps
rem	 - Bugfix: MPEG Transport Streams were not handled if certutil was not available
rem	 - Bugfix: MP3 audio files did not trigger audio file present flag
rem v3.3 2019/09/12 BrightSign - Brandon
rem	 - Bugfix: Only .mov files were being properly URL-encoded
rem      - Internal documentation additions
rem	 - Track audio/video/image file detection - warn at exit if audio mixed with video/images, or if feed is empty
rem	 - Add support for MPEG Transport Streams (handled as video files)
rem v3.2 2019/02/05 BrightSign - Brandon
rem      - If certutil is not available, fall back to using timestamp as GUID - note that this will cause the feed content to be redownloaded unnecessarily
rem	 - Replace default Base URL and Output Filename to placeholder values, check that they have been set, exit with error if not changed
rem      - Clarify TTL description (expiry vs refresh)
rem	 - Change to use WMIC to query date/time, eliminates regional settings variances
rem	 - Add filename to GUID
rem v3.1 2018/11/09 BrightSign - Brandon
rem      - Check to see that certutil.exe is available
rem v3.0 2018/11/09 BrightSign - Brandon
rem      - Switch GUID values to use SHA1 hash so unchanged files aren't redownloaded each time the feed is regenerated
rem      - Bugfix: Character escaping was only applied to .mov files
rem      - Bugfix: PNG base URLs were incorrect
rem v2.0 2017/07/10 BrightSign - Brandon
rem      - Handle special characters
rem initial BrightSign - Lyndon, Romeo
rem NOTES:
rem   0-byte files are ignored (seems to be a FOR loop thing)
rem   Mixing audio and video/images may not yield a feed the player can handle
rem   NOT SUPPORTED filenames containing the following characters:
rem     % ~
rem   PARTIALLY SUPPORTED (URL is correct, title is not) filenames containing the following characters:
rem     ; ,
rem Inputs:
rem   Video - .mov, .mp4, .mpg, .ts
rem   Image - .png, .jpeg, .jpg
rem   Audio - .mp3, .wav
rem --------------------

rem +===============================================+
rem + CONFIGURATION: Make changes to settings here! +
rem +===============================================+
rem   Edit the following lines to change the feed parameters and feed output filename

rem Base URL for where the files are located on the web server - MUST include trailing slash, internal servers should use FQDN
rem Example: http://192.168.1.10/mrss/  or  http://internalserver.mydomain.net/mrss/
SET BaseUrl=https://raw.githubusercontent.com/statik37/pegaFeed/main/

rem Image on-screen duration in seconds
SET TimeDisplayedOnScreenInSeconds=15

rem Feed TTL in minutes (a proper client will refresh the feed after this time) 
SET refreshfeedTimeinMinutes=5

rem Filename to generate the MRSS feed as - enclose in double-quotes (") if the filename/path has spaces
rem Example: C:\InetPub\wwwroot\MRSS\mrss.xml  or  "D:\For BrightSign\MRSS\feed.xml"
rem NOTE: Link tag of generated feed will not necessarily reflect the correct feed file's URL - this does not affect operation
rem NOTE: filename is *not* URL-escaped so avoid spaces and non-alphanumeric characters.
SET OutputFileName=feed.xml

rem +===============================================+
rem +             END OF CONFIGURATION              +
rem +===============================================+


rem =====================DO NOT CHANGE ANYTHING BELOW THIS LINE=====================

SET "header1=^<?xml version="1.0" encoding="utf-8" ?^>"
SET "header2=^<rss version="2.0" xmlns:media="http://search.yahoo.com/mrss/"^>"
SET "header3=^<channel^>"
SET "header4=  ^<title^>Batch Custom Video/Image/Audio MRSS template for BrightSign Players^</title^>"
SET "header5=  ^<link^>%BaseUrl%%OutputFileName%^</link^>"
SET "header6=  ^<generator^>Video/Image/Audio MRSS Generation Batch File^</generator^>"
SET "header7=  ^<ttl^>%refreshfeedTimeinMinutes%^</ttl^>"
SET "footer1=^</channel^>"
SET "footer2=^</rss^>"

SET haveCertUtil=0
SET haveAudioFiles=0
SET haveVideoFiles=0
SET haveImageFiles=0

rem This is a workaround for equal signs getting stripped out of ECHO due to other processing
SET "EQ_Sign=^="
SET "AMP_Sign=^&"


rem -----Start Main Code-----

rem Check prerequisites
ECHO %0 executing...
ECHO Running preflight checks...
MORE <NUL
ECHO Checking for external utilities...

rem Timestamp utilities
rem Check for PowerShell (used for generating timestamp for GUID)
ECHO - PowerShell ^(Used to generate GUID timestamp^)
WHERE /q PowerShell.exe
IF %ERRORLEVEL% EQU 0 (
	ECHO - - OK
	SET havePowerShell=1
) ELSE (

	ECHO ! - PowerShell.exe not found
	SET havePowerShell=0
)

rem Check for WMIC (used for generating timestamp for GUID)
ECHO - WMIC ^(Used to generate GUID timestamp^)
WHERE /q WMIC.exe
IF %ERRORLEVEL% EQU 0 (
	ECHO - - OK
	SET haveWMIC=1
) ELSE (
	ECHO ! - WMIC.exe not found
	SET haveWMIC=0
)

IF %havePowerShell% GTR 0 (
	ECHO - Generating timestamp via PowerShell
	rem Use PowerShell to get date/time variables to avoid regional settings messing things up
	rem yields Day, DayOfWeek, Hour, Milliseconds (may be blank), Minute, Month, Quarter, Second, WeekInMonth, Year, other variables
	FOR /F "usebackq tokens=1,2 delims=: " %%G IN (`PowerShell -command Get-WmiObject -class Win32_LocalTime ^| find ":"`) DO (CALL SET %%G=%%H)
) ELSE (
	IF %haveWMIC% GTR 0 (
		ECHO - Generating timestamp via WMIC
		rem Use WMIC to get date/time variables to avoid regional settings messing things up, thanks https://ss64.com/nt/syntax-gmt.html
		rem yields Day, DayOfWeek, Hour, Milliseconds (may be blank), Minute, Month, Quarter, Second, WeekInMonth, Year variables
		FOR /F "usebackq tokens=1,2 delims==" %%G IN (`wmic path Win32_LocalTime get /value ^| find "="`) DO (CALL SET %%G=%%H)
	) ELSE (
		ECHO - Generating random timestamp
		rem Have neither PowerShell nor WMIC, set Hour/Minute/Second/Day/Month to random
		SET Hour=%random%
		SET Minute=%random%
		SET Second=%random%
		SET Day=%random%
		SET Month=%random%
		SET Year=%random%
	)
)

rem Add leading zeroes
SET Hour=0%Hour%
SET Hour=%Hour:~-2%
SET Minute=0%Minute%
SET Minute=%Minute:~-2%
SET Second=0%Second%
SET Second=%Second:~-2%
SET Day=0%Day%
SET Day=%Day:~-2%
SET Month=0%Month%
SET Month=%Month:~-2%

ECHO - - Current timestamp: %Year%%Month%%Day%T%Hour%%Minute%%Second%
MORE <NUL

ECHO - certutil.exe ^(We need this to generate GUID hashes^)
WHERE /q certutil.exe
IF %ERRORLEVEL% EQU 0 (
	ECHO - - OK
	SET haveCertUtil=1
) ELSE (
	ECHO ! - certutil.exe not found
	ECHO ! - Falling back to using timestamps for GUIDs.
	ECHO ! - Note that this may cause feed content to be redownloaded unnecessarily at feed updates.
	SET haveCertUtil=0
)
MORE <NUL

ECHO Checking configuration...
IF %BaseUrl% == undefined (
	ECHO - Base URL not set in configuration section!!
	ECHO - - Edit the SET BaseUrl= line in the configuration section of %0
	EXIT /B 1
)
IF %OutputFileName% == undefined (
	ECHO - Output Filename not set in configuration section!!
	ECHO - - Edit the SET OutputFileName= line in the configuration section of %0
	EXIT /B 2
)
IF NOT %BaseUrl:~-1% == / (
	rem Trailing slash on Base URL is REQUIRED!  (We can't add it automatically because delayed expansion is disabled - and enabling it will screw things up)
	ECHO - Trailing slash on Base URL is REQUIRED!
	ECHO - - Edit the SET BaseUrl= line in the configuration section of %0 to include a / at the end
	EXIT /B 3
)
ECHO Base URL:                              %BaseUrl%
ECHO Images Displayed On Screen For:        %TimeDisplayedOnScreenInSeconds% seconds
ECHO Feed Time To Live ^(TTL^) Before Expiry: %refreshfeedTimeinMinutes% minutes
MORE <NUL
ECHO Generating feed...
(
	ECHO(%header1%
	ECHO(%header2%
	ECHO(%header3%
	ECHO(%header4%
	ECHO(%header5%
	ECHO(%header6%
	ECHO(%header7%

	rem We don't need delayed expansion here or we'll have additional escaping
	FOR %%A IN (*) DO (
		IF %haveCertUtil% EQU 1 (
			rem Generate GUID as file hash so it automatically changes if file content changes - and doesn't otherwise
			FOR /F "skip=1 tokens=1 usebackq eol=C" %%B IN (`CertUtil -hashfile "%%A" SHA1`) DO (
	
				rem Call subroutines to output, avoiding delayed expansion headaches
				rem First parameter is filename
				rem Second parameter is GUID
	
				rem Video
				IF /I %%~xA == .mov CALL :outputVideoMOV "%%A" %%B
				IF /I %%~xA == .mp4 CALL :outputVideoMPEG "%%A" %%B
				IF /I %%~xA == .mpg CALL :outputVideoMPEG "%%A" %%B
				IF /I %%~xA == .ts CALL :outputVideoMPEG "%%A" %%B

				rem Images
				IF /I %%~xA == .jpg CALL :outputImageJPEG "%%A" %%B
				IF /I %%~xA == .jpeg CALL :outputImageJPEG "%%A" %%B
				IF /I %%~xA == .png CALL :outputImagePNG "%%A" %%B
	
				rem Audio
				IF /I %%~xA == .mp3 CALL :outputAudioMP3 "%%A" %%B
				IF /I %%~xA == .wav CALL :outputAudioWAV "%%A" %%B
			)
		) ELSE (
			rem We don't have certutil.exe so use filename+timestamp as GUID
			rem Call subroutines to output, avoiding delayed expansion headaches
			rem First parameter is filename
			rem Second parameter is timestamp
			
			rem Video
			IF /I %%~xA == .mov CALL :outputVideoMOV "%%A" "%Year%-%Month%-%Day%T%Hour%:%Minute%:%Second%"
			IF /I %%~xA == .mp4 CALL :outputVideoMPEG "%%A" "%Year%-%Month%-%Day%T%Hour%:%Minute%:%Second%"
			IF /I %%~xA == .mpg CALL :outputVideoMPEG "%%A" "%Year%-%Month%-%Day%T%Hour%:%Minute%:%Second%"
			IF /I %%~xA == .ts CALL :outputVideoMPEG "%%A" "%Year%-%Month%-%Day%T%Hour%:%Minute%:%Second%"

			rem Images
			IF /I %%~xA == .jpg CALL :outputImageJPEG "%%A" "%Year%-%Month%-%Day%T%Hour%:%Minute%:%Second%"
			IF /I %%~xA == .jpeg CALL :outputImageJPEG "%%A" "%Year%-%Month%-%Day%T%Hour%:%Minute%:%Second%"
			IF /I %%~xA == .png CALL :outputImagePNG "%%A" "%Year%-%Month%-%Day%T%Hour%:%Minute%:%Second%"
	
			rem Audio
			IF /I %%~xA == .mp3 CALL :outputAudioMP3 "%%A" "%Year%-%Month%-%Day%T%Hour%:%Minute%:%Second%"
			IF /I %%~xA == .wav CALL :outputAudioWAV "%%A" "%Year%-%Month%-%Day%T%Hour%:%Minute%:%Second%"
		)
			
	)

	ECHO(%footer1%
	ECHO(%footer2%
)>%OutputFileName%

ECHO MRSS feed XML written to:               %OutputFileName%

rem Check feed content types
ECHO Feed contains:
IF %haveVideoFiles% EQU 1 ( ECHO [X] Video ) ELSE ( ECHO [ ] Video )
IF %haveImageFiles% EQU 1 ( ECHO [X] Image ) ELSE ( ECHO [ ] Image )
IF %haveAudioFiles% EQU 1 ( ECHO [X] Audio ) ELSE ( ECHO [ ] Audio )
MORE <NUL

rem Check for no items
IF %haveVideoFiles%==0 (
	IF %haveImageFiles%==0 (
		IF %haveAudioFiles%==0 (
			ECHO WARNING: Feed has no items!!!!
		)
	)
)

rem Check for Video+Image+Audio
IF %haveVideoFiles%==1 (
	IF %haveImageFiles%==1 (
		IF %haveAudioFiles%==1 (
			ECHO WARNING! Feed contains Video, Image, and Audio files - it may not play back properly!  For compatibility, do not combine Audio files with non-Audio files.
		)
	)
)

rem Check for Video+Audio
IF %haveVideoFiles%==1 (
	IF %haveImageFiles%==0 (
		IF %haveAudioFiles%==1 (
			ECHO WARNING! Feed contains both Video and Audio files - it may not play back properly!  For compatibility, do not combine Audio files with non-Audio files.
		)
	)
)

rem Check for Image+Audio
IF %haveVideoFiles%==0 (
	IF %haveImageFiles%==1 (
		IF %haveAudioFiles%==1 (
			ECHO WARNING! Feed contains both Image and Audio files - it may not play back properly!  For compatibility, do not combine Audio files with non-Audio files.
		)
	)
)


GOTO :end

rem =====End Main Code=====


rem Escape ECHO-special characters
rem NOTE: There's a HORRIBLE amount of chain-reactioning and order dependencies here
:echoEscape
	SET "echoname=%~nx1"
REM echo ---
REM echo Input ECHO name
REM echo %echoname%

	rem ^ -> ^^ (must be FIRST or we'll end up escaping the escape characters!)
	rem  this looks wrong, but SET needs it escaped, so we're actually doing ^ -> ^^
	SET "echoname=%echoname:^=^^^^%"

	rem = -> ^=
 	SET "tgt=%%EQ_Sign%%"
	Call :EQ_Replace echoname tgt

	rem & -> ^&
 	SET "tgt=%AMP_Sign%"
 	FOR /F "delims=" %%G IN ('cmd /v:on /c @echo %echoname:&=!tgt!%') DO (SET "echoname=%%~G")

REM echo Output ECHO name
REM echo %echoname%
REM echo ===
GOTO :eof


rem Encode filename for URL path
:urlEncode
	rem Generate URL path friendly filename
	SET "urlname=%~nx1"
REM echo ---
REM echo Input URL name
REM echo %urlname%
	rem URL: spaces -> %20
	SET "tgt2=%%20"
	FOR /F "delims=" %%G IN ('cmd /v:on /c @echo "%urlname: =!tgt2!%"') DO (SET "urlname=%%~G")

	rem URL: & -> %26
	SET "tgt2=%%26"
	FOR /F "delims=" %%G IN ('cmd /v:on /c @echo "%urlname:&=!tgt2!%"') DO (SET "urlname=%%~G")

	rem URL: $ -> %24
	SET "tgt2=%%24"
	FOR /F "delims=" %%G IN ('cmd /v:on /c @echo "%urlname:$=!tgt2!%"') DO (SET "urlname=%%~G")

	rem URL: + -> %2B
	SET "tgt2=%%2B"
	FOR /F "delims=" %%G IN ('cmd /v:on /c @echo "%urlname:+=!tgt2!%"') DO (SET "urlname=%%~G")

	rem URL: ` -> %60
	SET "tgt2=%%60"
	FOR /F "delims=" %%G IN ('cmd /v:on /c @echo "%urlname:`=!tgt2!%"') DO (SET "urlname=%%~G")

	rem URL: [ -> %5B
	SET "tgt2=%%5B"
	FOR /F "delims=" %%G IN ('cmd /v:on /c @echo "%urlname:[=!tgt2!%"') DO (SET "urlname=%%~G")

	rem URL: ] -> %5D
	SET "tgt2=%%5D"
	FOR /F "delims=" %%G IN ('cmd /v:on /c @echo "%urlname:]=!tgt2!%"') DO (SET "urlname=%%~G")

	rem URL: { -> %7B
	SET "tgt2=%%7B"
	FOR /F "delims=" %%G IN ('cmd /v:on /c @echo "%urlname:{=!tgt2!%"') DO (SET "urlname=%%~G")

	rem URL: } -> %7D
	SET "tgt2=%%7D"
	FOR /F "delims=" %%G IN ('cmd /v:on /c @echo "%urlname:}=!tgt2!%"') DO (SET "urlname=%%~G")

	rem URL: # -> %23
	SET "tgt2=%%23"
	FOR /F "delims=" %%G IN ('cmd /v:on /c @echo "%urlname:#=!tgt2!%"') DO (SET "urlname=%%~G")

	rem URL: ^ -> %5E
	rem  this looks wrong, but it actually works - single carets get escaped along with its escape at this level - ^ -> ^^ -> ^^^^
	SET "tgt2=%%5E"
	FOR /F "delims=" %%G IN ('cmd /v:on /c @echo "%urlname:^^^^=!tgt2!%"') DO (SET "urlname=%%~G")
	
	rem URL: ' -> %27
	SET "tgt2=%%27"
	FOR /F "usebackq delims=" %%G IN (`cmd /v:on /c @echo "%urlname:'=!tgt2!%"`) DO (SET "urlname=%%~G")

	rem URL: , -> %2C
	SET "tgt2=%%2C"
	FOR /F "delims=" %%G IN ('cmd /v:on /c @echo "%urlname:,=!tgt2!%"') DO (SET "urlname=%%~G")

	rem URL: = -> %3D
	SET "tgt2=%%3D"
	Call :EQ_Replace urlname tgt2

REM echo Output URL name
REM echo %urlname%
REM echo ===
GOTO :eof


rem This subroutine adapted from amel27 at http://dostips.com/forum/viewtopic.php?t=1485
rem It's a bit heavy, so we use other means when possible, but it's necessary for replacing =
:EQ_Replace  %VarString%  %VarReplacement%
::----------------------------------------
(SETLOCAL EnableDelayedExpansion
Set "$_=!%~1!|"
Set "$f=1"
Set "$v="
For /L %%i In (0,1,55) Do If Defined $f (
    For /F "Delims==" %%a In ('Set $_') Do (
        Set "$a=%%a"& Set "$b=!%%a!"
        Set "%%a="& Set "$_!$b!"2>Nul ||Set "$f="
        If %%i gtr 0 Set "$v=!$v!!$a:~2!!%~2!"
        If '%$f%'=='' (
            rem This appends the remaining characters after the last = because they get left behind for some reason
            Set "result=!$v!!$b!"
          )
      )
  )
rem This drops the trailing | that is stuck to the end of $b (and therefore result) above
For /F "Delims=| tokens=1" %%a In ("!result!") Do ENDLOCAL& Set "%~1=%%a"
GoTo :EOF)


rem Common header for all supported items
rem 1st parameter is filename
rem 2nd parameter is GUID
:outputCommonHeader
	ECHO(    ^<item^>
	ECHO(        ^<title^>%echoname%^</title^>
	ECHO(        ^<pubDate^>%Year%-%Month%-%Day%T%Hour%:%Minute%:%Second%.000z^</pubDate^>
	ECHO(        ^<link^>%BaseUrl%%urlname%^</link^>
	ECHO(        ^<description^>%echoname%^</description^>
	ECHO(        ^<guid^>%~nx1%~2^</guid^>
GOTO :eof


rem Common footer for all supported items
:outputCommonFooter
    ECHO(    ^</item^>
GOTO :eof


rem Video item - Quicktime MOV
:outputVideoMOV
	SET haveVideoFiles=1
	CALL :echoEscape %1
	CALL :urlEncode %1
	CALL :outputCommonHeader %1 %2
	ECHO(        ^<media:content url=^"%BaseUrl%%urlname%^" fileSize="%~z1" type=^"video/quicktime^" medium=^"video^"/^>
	CALL :outputCommonFooter
GOTO :eof


rem Video item - MPEG
:outputVideoMPEG
	SET haveVideoFiles=1
	CALL :echoEscape %1
	CALL :urlEncode %1
	CALL :outputCommonHeader %1 %2
	ECHO(        ^<media:content url=^"%BaseUrl%%urlname%^" fileSize="%~z1" type=^"video/mp4^" medium=^"video^"/^>
	CALL :outputCommonFooter %1
GOTO :eof


rem Image item - JPEG
:outputImageJPEG
	SET haveImageFiles=1
	CALL :echoEscape %1
	CALL :urlEncode %1
	CALL :outputCommonHeader %1 %2
	ECHO(        ^<media:content url=^"%BaseUrl%%urlname%^" fileSize="%~z1" type=^"image/jpeg^" medium=^"image^" duration=^"%TimeDisplayedOnScreenInSeconds%^"/^>
	CALL :outputCommonFooter %1
GOTO :eof


rem Image item - PNG
:outputImagePNG
	SET haveImageFiles=1
	CALL :echoEscape %1
	CALL :urlEncode %1
	CALL :outputCommonHeader %1 %2
	ECHO(        ^<media:content url=^"%BaseUrl%%urlname%^" fileSize="%~z1" type=^"image/png^" medium=^"image^" duration=^"%TimeDisplayedOnScreenInSeconds%^"/^>
	CALL :outputCommonFooter %1
GOTO :eof


rem Audio item - WAV
:outputAudioWAV
	SET haveAudioFiles=1
	CALL :echoEscape %1
	CALL :urlEncode %1
	CALL :outputCommonHeader %1 %2
	ECHO(        ^<media:content url=^"%BaseUrl%%urlname%^" fileSize="%~z1" type=^"audio/wave^" medium=^"audio^"/^>
	CALL :outputCommonFooter %1
GOTO :eof


rem Audio item - MP3
:outputAudioMP3
	SET haveAudioFiles=1
	CALL :echoEscape %1
	CALL :urlEncode %1
	CALL :outputCommonHeader %1 %2
	ECHO(        ^<media:content url=^"%BaseUrl%%urlname%^" fileSize="%~z1" type=^"audio/mpeg^" medium=^"audio^"/^>
	CALL :outputCommonFooter %1
GOTO :eof

:end