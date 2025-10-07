@echo off
REM Get 1st arg in %DIR% converted by winepath
for /F "tokens=* USEBACKQ" %%F in (`winepath %1`) do (set "DIR=%%F")
shift
REM Get 2nd arg in %SRC% converted by winepath
for /F "tokens=* USEBACKQ" %%F in (`winepath %1`) do (set "SRC=%%F")
shift
REM Store remaining args in %CMD%. Beware of %* and shift
set "CMD=%1 %2 %3 %4 %5 %6 %7 %8 %9"
REM Pause after build, in second or -1 for infinite
set "PAUSE=3"
REM Enable debuging
set "DBG=set +vx"
REM Enable echoing
set "ECHOING=true"
REM Execute linux shell command
cmd /c start /unix /usr/bin/xterm -bg black -fg white -e "/bin/sh -c ':; %DBG%; set +e; %ECHOING% [DBG] directory: $1; cd $1; shift; shift; %ECHOING% [DBG] command: $@; %ECHOING%; $@; RET=$?; echo; %ECHOING% [DBG] return code: $RET; if test \"%PAUSE%\" = \"-1\"; then echo Press enter to exit...; read _; elif test -n \"%PAUSE%\"; then sleep %PAUSE%; fi; exit $RET' _ %DIR% %SRC% %CMD%"
