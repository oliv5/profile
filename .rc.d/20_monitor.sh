#!/bin/sh

################################
# Get system info
# http://jeffskinnerbox.me/posts/2014/Mar/31/howto-linux-maintenance-and-filesystem-hygiene/
alias kernel_name='uname -sr'
alias kernel_ver='uname -v'
alias dist_name='cat /etc/*-release'
alias dist_ver='lsb_release -a'
alias disk_info='sudo lshw -class disk -class storage -short'
alias disk_drive='hwinfo --disk --short'
alias rpi_fw='/opt/vc/bin/vcgencmd version'

# Drivers
alias lsmodg='lsmod | grep -i'
alias modinfog='modinfo | grep -i'
alias dmesgg='dmesg | grep -i'

################################
# https://wiki.archlinux.org/title/CPU_frequency_scaling
# Get/set cpu governor
cpu_governor() {
  local DEV="/sys/devices/system/cpu/cpu${2:-*}/cpufreq/scaling_governor"
  if [ -n "$1" ]; then sudo sh -c "echo '$1' > '$DEV'"; else cat "$DEV"; fi
}
alias cpu_governors='cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_available_governors'
alias cpu_powersave='cpu_governor powersave'
alias cpu_performance='cpu_governor performance'
alias cpu_ondemand='cpu_governor ondemand'
alias cpu_conservative='cpu_governor conservative'
alias cpu_schedutil='cpu_governor schedutil'
alias cpu_userspace='cpu_governor userspace'

# CPU frequencies
cpu_curfreq() {
  local DEV="/sys/devices/system/cpu/cpu${2:-*}/cpufreq/scaling_cur_freq"
  if [ -n "$1" ]; then sudo sh -c "echo '$1' > '$DEV'"; else cat "$DEV"; fi
}
cpu_minfreq() {
  local DEV="/sys/devices/system/cpu/cpu${2:-*}/cpufreq/scaling_min_freq"
  if [ -n "$1" ]; then sudo sh -c "echo '$1' > '$DEV'"; else cat "$DEV"; fi
}
cpu_maxfreq() {
  local DEV="/sys/devices/system/cpu/cpu${2:-*}/cpufreq/scaling_max_freq"
  if [ -n "$1" ]; then sudo sh -c "echo '$1' > '$DEV'"; else cat "$DEV"; fi
}

################################
# TTys
alias tty_list='ps aux|grep /usr/bin/[X]'
alias tty_active='cat /sys/class/tty/tty0/active'
alias tty_next='sudo fgconsole'

# Find display
show_display() {
  ps a | grep -E '[X]org' | sed -e 's/^.*\(:[0-9]\+\).*$/\1/g'
}
show_display_local() {
  for x in /tmp/.X11-unix/X*; do echo ":${x##*X}"; done
}
show_display_remote() {
  netstat -lnt | awk '
    sub(/.*:/,"",$4) && $4 >= 6000 && $4 < 6100 {
      print ($1 == "tcp6" ? "ip6-localhost:" : "localhost:") ($4 - 6000)
    }'
}

################################
# Grep process IDs
psgp(){
  ps aux | awk "/$1/ "'{print $2}'
}

# User processes
pgu() {
  pgrep -flu "$(id -u ${1:-$USER})"
}
psgu() {
  local USER="${1:-$USER}"
  shift
  psu "$USER" | grep -i "$@"
}

# List of PIDs
if ! command -v isint >/dev/null; then
  isint() { expr 1 "*" "$1" + 1 > /dev/null 2>&1; }
fi
if ! command -v pidof >/dev/null; then
  alias pidof='pid'
fi
pid() {
  # Use xargs to trim leading spaces
  #[ $# -gt 0 ] && ps -C "$@" -o pid= | xargs
  for ARG; do
    { isint "$ARG" && ps -p "$ARG" -o pid= || ps -C "$ARG" -o pid=; } | xargs
  done
}

# List of UIDs
uid() {
  # Use xargs to trim leading spaces
  #[ $# -gt 0 ] && ps -C "$@" -o user= | xargs
  for ARG; do
    { isint "$ARG" && ps -p "$ARG" -o user= || ps -C "$ARG" -o user=; } | xargs
  done
}

# List of PPIDs
alias ppidof='ppid'
ppid() {
  # Use xargs to trim leading spaces
  #[ $# -gt 0 ] && ps -C "$@" -o ppid= | xargs
  for ARG; do
    { isint "$ARG" && ps -p "$ARG" -o ppid= || ps -C "$ARG" -o ppid=; } | xargs
  done
}
ppidn() {
  local PID="${1}"
  local ITER="${2:-0}"
  shift
  for I in $(seq 1 ${ITER}); do
    [ -z "$PID" ] && break
    PID="$(ps -p "$PID" -o ppid=)"
  done
  echo "$PID"
}

# List of zombies
#http://www.noah.org/wiki/Kill_-9_does_not_work
psz() {
  ps aux | awk '"[ZzDd]" ~ $8'
  #ps Haxwwo stat,pid,ppid,user,wchan:25,command | grep -e "^STAT" -e "^D" -e "^Z"
}

# Ps process parent
psp() {
  for ARG; do
    for PID in $(ppid $ARG); do
      ps u -p "$PID"
    done
  done
}

################################
# Wait for process (even not our children)
waitpid(){
  for pid; do
    while kill -0 "$pid" 2>/dev/null; do
      sleep 0.5
    done
  done
}

################################
# System information
sys_iostat() {
  iostat -x 2
}

sys_stalled() {
  while true; do ps -eo state,pid,cmd | grep "^D"; echo "—-"; sleep 1; done
}

sys_cpu() {
  sar ${1:-1} ${2}
}

# https://stackoverflow.com/questions/666783/how-to-find-out-which-process-is-consuming-wait-cpu-i-e-i-o-blocked
io_stalled() {
  while true; do date; ps auxf | awk '{if($8=="D") print $0;}'; sleep 1; done
}

################################
# Memory information
mem() { free -mt --si; }
mem_free()   { free | cut -d: -f 2- | awk 'FNR==2 {print $3}'; }
swap_free()  { free | cut -d: -f 2- | awk 'FNR==3 {print $3}'; }
mem_used()   { free | cut -d: -f 2- | awk 'FNR==2 {print $2}'; }
swap_used()  { free | cut -d: -f 2- | awk 'FNR==3 {print $2}'; }
mem_total()  { free | cut -d: -f 2- | awk 'FNR==2 {print $1}'; }
swap_total() { free | cut -d: -f 2- | awk 'FNR==3 {print $1}'; }

################################
# Processes information
alias cpu='cpu_ps'

cpu_ps() {
  # use eval because of the option "|" in $1
  eval ps ${2:-aux} ${1:+| grep $1} | awk 'BEGIN {sum=0} {sum+=$3}; END {print sum}'
}

mem_ps() {
  # use eval because of the option "|" in $1
  eval ps ${2:-aux} ${1:+| grep $1} | awk 'BEGIN {sum=0} {sum+=$4}; END {print sum}'
}

cpu_list() {
  local NUM=$((${1:-1} + 1))
  shift $(min 1 $#)
  # use eval because of the option "|" in $1
  eval ps ${@:-aux} --sort -%cpu ${NUM:+| head -n $NUM}
}

mem_list() {
  local NUM=$((${1:-1} + 1))
  shift $(min 1 $#)
  # use eval because of the option "|" in $1
  eval ps ${@:-aux} --sort -rss ${NUM:+| head -n $NUM}
}

cpu_listshort() {
  cpu_list "$1" ax -o comm,pid,%cpu,cpu
}

mem_listshort() {
  mem_list "$1" ax -o comm,pid,pmem,rss,vsz
}

# Aggregated top cpu hungry processes
cpu_top() {
  printf "%-20s\t%%CPU\n" "COMMAND"
  ps -A -o comm,pcpu | awk '
  NR == 1 { next }
  { a[$1] += $2 }
  END {
    for (i in a) {
      printf "%-20s\t%.2f\n", i, a[i]
    }
  }
' | LC_ALL=C sort -rnk2 | less
}

# Aggregated top mem hungry processes
# http://www.zyxware.com/articles/4446/show-total-memory-usage-by-each-application-in-your-ubuntu-or-any-gnu-linux-system
mem_top() {
  printf "%-20s\t%%MEM\tSIZE\n", "COMMAND"
  ps -A --sort -rss -o comm,pmem,rss | awk '
  NR == 1 { next }
  { a[$1] += $2; b[$1] += $3; }
  END {
    for (i in a) {
      size_in_bytes = b[i] * 1024
      split("B KB MB GB TB PB", unit)
      human_readable = 0
      if (size_in_bytes == 0) {
        human_readable = 0
        j = 0
      }
      else {
        for (j = 5; human_readable < 1; j--)
          human_readable = size_in_bytes / (2^(10*j))
      }
      printf "%-20s\t%s\t%.2f%s\n", i, a[i], human_readable, unit[j+2]
    }
  }
' | LC_ALL=C sort -rbhk3 | less
}

################################
# Kill top cpu/mem hungry processes
kill_top_cpu() {
  local NUM=$((${1:-1} + 1))
  shift $(min 1 $#)
  ps a --sort -%cpu | awk 'NR>1 && NR<=$NUM {print $1;}' | xargs -r kill "$@"
}

kill_top_mem() {
  local NUM=$((${1:-1} + 1))
  shift $(min 1 $#)
  ps a --sort -rss | awk 'NR>1 && NR<=$NUM {print $1;}' | xargs -r kill "$@"
}

################################
# Kill zombie by killing rpciod too
# http://www.noah.org/wiki/Kill_-9_does_not_work
killz(){
  kill -9 "$@"
  ps Haxwwo pid,command | awk '/rpciod/ && !/grep/ {print $1}' | xargs -r kill
}
killza() {
  kill -HUP $(ps -A -ostat,ppid | awk '/[zZ]/ && !a[$2]++ {print $2}')
}

# Kill all zombies by detaching them from their parent
killz_detach() {
  local _PID _PPID
  ps -e -o pid,ppid,state,comm |
    awk '"[Zz]" ~ $3 { printf("%d %d %s\n", $1, $2, $4); }' |
      while IFS=$' \n' read _PID _PPID _NAME; do
        echo "Kill zombie $_NAME (PID: $_PID PPID: $_PPID)"
        gdb -q -nx -ex "attach $_PPID" -ex "call waitpid($_PID, 0, 0)" -ex "detach"
      done
}

################################
# User list - uid can be specified
user_list() {
  getent passwd "$@"
}
# User name - uid can be specified
user_name() {
  getent passwd "$@" | awk -F: '{print $1}'
}

################################
# IPC management
ipc_sempurge() {
  ipcs -s | awk '/0/ {print $2}' | xargs -r -n 1 ipcrm -s
}
ipc_shmpurge() {
  ipcs -m | awk '/0/ {print $2}' | xargs -r -n 1 ipcrm -m
}
ipc_semuser() {
  awk '$5~/[0-9]+/ {print $5}' /proc/sysvipc/sem | sort | uniq | xargs getent passwd | awk -F: '{print $1}'
}
ipc_semstat() {
  echo -e "uid\tnum"
  awk '$5~/[0-9]+/ {print $5}' /proc/sysvipc/sem | sort | uniq -c | sort -r | awk '{print $2 "\t" $1}'
}
ipc_semstatn() {
  #awk '$5~/[0-9]+/ {print $5}' /proc/sysvipc/sem | sort | uniq -c | sort -r | awk '{system("getent passwd " $2 " | cut -d: -f 1"); print $1}'
  awk '$5~/[0-9]+/ {print $5}' /proc/sysvipc/sem | sort | uniq -c | sort -r | awk '{printf $1; "getent passwd " $2 " | cut -d: -f 1" | getline; print " "$1}'
}

################################
lsof_deleted() {
    sudo lsof -nP | grep '(deleted)'
}

lsof_close(){
  # For all open but deleted files associated with process 2746, trunctate the file to 0 bytes
  local PID="${1:?No PID specified...}"
  cd /proc/$PID/fd 
  ls -l | grep '(deleted)' | awk '{ print $9 }' | while read FILE; do :> /proc/$PID/fd/$FILE; done
}
