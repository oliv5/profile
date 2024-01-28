#!/bin/sh
# From https://calomel.org/dns_verify.html
NETS="$(ip addr | awk '/inet .*\/24/{print $2}' | grep -Fv 127.0.0.1 | xargs)"
NETS_SKIPPED="$(ip addr | awk '/inet .*\/16/{print $2}' | grep -Fv 127.0.0.1 | xargs)"
echo "Adresses queried: $NETS"
echo "Adresses skipped: $NETS_SKIPPED"
echo ""
printf "     ip          -> hostname \t\t -> ip"
echo ""
echo "--------------------------------------------------------"
for NET in $NETS; do
  NET="${NET%.*}"
  for n in $(seq 1 254); do
    A="${NET}.${n}"
    HOST="$(dig -x "$A" +short | xargs)"
    if test -n "$HOST"; then
      ADDR="$(dig $HOST +short 2>/dev/null | xargs)"
      if test "$A" = "$ADDR"; then
        printf "ok   $A -> $HOST\t -> $ADDR"
      elif echo "$ADDR" | grep -F "$A" >/dev/null; then
        printf "ok   $A -> $HOST\t -> [ $ADDR ]"
      elif test -n "$ADDR"; then
        printf "fail $A -> $HOST\t -> $ADDR"
      else
        printf "fail $A -> $HOST\t -> [unassigned]"
      fi
      echo ""
    fi
  done
done

echo ""
echo "DONE."
