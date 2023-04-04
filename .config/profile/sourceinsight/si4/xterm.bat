@echo off
REM Execute linux shell command
FOR /F "tokens=* USEBACKQ" %%F IN (`winepath %1`) DO (SET "DIR=%%F")
set "CMD=%*"
cmd /c start /unix /usr/bin/xterm -e "/bin/sh -c 'set +e; set -vx; cd \"$(readlink -f \"$1\")\" && shift 2 && pwd && \"$@\"; RET=$?; read -p \"Enter to quit...\" _; exit $RET' _ %DIR% %CMD%"
