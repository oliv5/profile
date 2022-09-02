#!/bin/sh
# From https://calomel.org/dns_verify.html
NETS="$(ip addr | awk '/inet .*\/24/{print $2}' | grep -Fv 127.0.0.1 | xargs)"
echo Analyse addresses: $NETS
echo
echo -e "\tip        ->     hostname      -> ip"
echo '--------------------------------------------------------'  
for NET in $NETS; do
  NET="${NET%.*}"
  for n in $(seq 1 254); do
    A="${NET}.${n}"
    HOST="$(dig -x "$A" +short)"
    if test -n "$HOST"; then
      ADDR="$(dig $HOST +short)"
      if test "$A" = "$ADDR"; then
        echo -e "ok\t$A -> $HOST -> $ADDR"
      elif test -n "$ADDR"; then
        echo -e "fail\t$A -> $HOST -> $ADDR"
      else
        echo -e "fail\t$A -> $HOST -> [unassigned]"
      fi
    fi
  done
done

echo ""
echo "DONE."
