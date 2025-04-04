#!/bin/sh

################################
# Computations
min() { echo $((${1:-0}<${2:-0}?${1:-0}:${2:-0})); }
max() { echo $((${1:-0}>${2:-0}?${1:-0}:${2:-0})); }
bound() { max $(min $1 $3) $2; }
isint() { expr 1 "*" "$1" + 1 >/dev/null 2>&1; }
toint() { expr 1 "*" "$1" 2>/dev/null || echo 0; }
alias avg="awk '{a+=\$1} END{print a/NR}'"

# Conversion to (unsigned) integer
_int() {
  local MAX="${1:?No maximum value specified...}"
  shift
  for RES in ${@:-0}; do
    RES="$(echo $RES | bc)"
    [ "$RES" -ge "$MAX" ] && RES="$((RES-2*MAX))"
    echo "$RES"
  done
}
alias int='int32'
alias int8='_int $((1<<7))'
alias int16='_int $((1<<15))'
alias int32='_int $((1<<31))'
alias int64='_int $((1<<63))'
alias uint='uint32'
alias uint8='_int $((1<<8))'
alias uint16='_int $((1<<16))'
alias uint32='_int $((1<<32))'
alias uint64='_int $((1<<64))'

# Computations using bc
# Note: always set "ibase" last !
alias int2bin='calc "obase=2;"'
alias bin2int='calc "ibase=2;"'
alias int2hex='calc "obase=16;"'
alias hex2int='calc "ibase=16;"'
alias bin2hex='calc "obase=16;ibase=2;"'
alias hex2bin='calc "obase=2;ibase=16;"'
calc() {
  echo "$@" | bc
}

# File conversion using bc
alias fint2hex='fcalc 16'
alias fhex2int='fcalc 10'
fcalc() {
  ( echo "obase=$1"; shift; cat "$@" ) | bc
}

# Hexdump to txt
fbin2hex() {
  hexdump "$@" -ve '1/4 "0x%.8x\n"'
}

# Hexwrite byte
# $1: file
# $2: offset
# $3: dec value
hexwrite() {
  printf '\\x%s' "$3" | dd of="$1" bs=1 seek="$2" count=1 conv=notrunc &> /dev/null
}

# Sum pipe input
alias sum="awk 'BEGIN{a=0}{a=a+\$0}END{print a}'"

# Make a sum of all inputs
add() {
  local RES=0
  for I; do
    RES=$(($RES+$I))
  done
  echo $RES
}

# Substract ($2+$3+...$n) to $1
sub() {
  local RES=${1:-0}
  shift $(($#>0?1:0))
  for I; do
    RES=$(($RES-$I))
  done
  echo $RES
}

################################
# Floating point operations
# See http://unix.stackexchange.com/questions/40786/how-to-do-integer-float-calculations-in-bash-or-other-languages-frameworks
#
#echo "$((20.0/7))"
#awk "BEGIN {print (20+5)/2}"
#zcalc
#bc <<< 20+5/2
#bc <<< 'scale=4;20+5/2'
#expr 20 + 5
#calc 2 + 4
#node -pe 20+5/2  # Uses the power of JavaScript, e.g. : node -pe 20+5/Math.PI
#echo 20 5 2 / + p | dc 
#echo 4 k 20 5 2 / + p | dc 
#perl -E "say 20+5/2"
#python -c "print 20+5/2"
#python -c "print 20+5/2.0"
#clisp -x "(+ 2 2)"
#lua -e "print(20+5/2)"
#php -r 'echo 20+5/2;'
#ruby -e 'p 20+5/2'
#ruby -e 'p 20+5/2.0'
#guile -c '(display (+ 20 (/ 5 2)))'
#guile -c '(display (+ 20 (/ 5 2.0)))'
#slsh -e 'printf("%f",20+5/2)'
#slsh -e 'printf("%f",20+5/2.0)'
#tclsh <<< 'puts [expr 20+5/2]'
#tclsh <<< 'puts [expr 20+5/2.0]'
#sqlite3 <<< 'select 20+5/2;'
#sqlite3 <<< 'select 20+5/2.0;'
#echo 'select 1 + 1;' | sqlite3 
#psql -tAc 'select 1+1'
#R -q -e 'print(sd(rnorm(1000)))'
#r -e 'cat(pi^2, "\n")'
#r -e 'print(sum(1:100))'
#smjs
#jspl


################################
# Random number generators
# https://www.cyberciti.biz/faq/bash-shell-script-generating-random-numbers/
urandint() {
  od -vAn -N4 -tu4 < /dev/urandom | tr -d ' '
}
randint() {
  od -An -N2 -i /dev/random | tr -d ' '
}
urandbyte() {
  od -A n -N1 -t d2 /dev/random | tr -d ' '
}
randbyte() {
  od -A n -N1 -t d1 /dev/random | tr -d ' '
}

################################
# Convert HH:mm:ss.ms into seconds
tosec(){
  for INPUT; do
    echo "$INPUT" | awk -F'[:.]' '{ for(i=0;i<2;i++){if(NF<=2){$0=":"$0}}; print ($1 * 3600) + ($2 * 60) + $3 }'
  done
}
tosecms(){
  for INPUT; do
    echo "$INPUT" | awk -F: '{ for(i=0;i<2;i++){if(NF<=2){$0=":"$0}}; print ($1 * 3600) + ($2 * 60) + $3 }'
  done
}
toms(){
  for INPUT; do
    echo "$INPUT" | awk -F: '{ for(i=0;i<2;i++){if(NF<=2){$0=":"$0}}; print (($1 * 3600) + ($2 * 60) + $3) * 1000 }'
  done
}

################################
# Basic stats
stats() {
  echo "$@" | tr ' ' '\n' | sort -n |
  awk -F'=|/' '
BEGIN {
  c = 0
  sum = 0
}
$1 ~ /^(\-)?[0-9]*(\.[0-9]*)?$/ {
  a[c++] = $1
  sum += $1
}
END {
  ave = sum / c;
  if( (c % 2) == 1 ) {
    median = a[ int(c/2) ]
  } else {
    median = ( a[c/2] + a[c/2-1] ) / 2
  }
  var = 0
	for (i = 0; i < c; i++) {
		d = (a[i] - ave)
		var += (d * d)
	}
	var /= c
	std = sqrt(var)
  OFS="\t"
  print sum, c, ave, median, a[0], a[c-1], var, std, ave-std, ave+std
}
'
}

sum_serie() {
  stats "$@" | cut -f 1
}

num_serie() {
  stats "$@" | cut -f 2
}

alias avg_serie='mean_serie'
mean_serie() {
  stats "$@" | cut -f 3
}

median_serie() {
  stats "$@" | cut -f 4
}

min_serie() {
  stats "$@" | cut -f 5
}

max_serie() {
  stats "$@" | cut -f 6
}

var_serie() {
  stats "$@" | cut -f 7
}

std_serie() {
  stats "$@" | cut -f 8
}

avg_minus_std_serie() {
  stats "$@" | cut -f 9
}

avg_plus_std_serie() {
  stats "$@" | cut -f 10
}
