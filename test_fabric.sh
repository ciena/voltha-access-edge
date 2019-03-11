#!/usr/bin/env bash

VMS="management compute1 compute2 compute3 olt"
IPS="10.1.1.3 10.1.2.3 10.1.3.3 10.1.4.3 10.1.4.4"
GREEN='\033[1;32m'
RED='\033[1;31m'
RESET='\033[1;0m'

trap ctrl_c INT
function ctrl_c() {
    exit 1
}

GOOD=0
for C in $VMS; do
    echo -n "TEST: $C ... "
    FAILED=$(2>&1 vagrant ssh $C -- "bash -c 'O=""; for I in $IPS; do ping -c 1 -W 1 \$I >/dev/null 2>&1; if [ \$? -ne 0 ]; then O=\"\$I \$O\"; fi; done 2>&1; echo \$O'")
    if [ $? -ne 0 -o "$FAILED x" != " x" ]; then
        echo -e "${RED}FAILED${RESET} ($FAILED)"
        GOOD=1
    else
        echo -e "${GREEN}PASS${RESET}"
    fi
done

if [ $GOOD -eq 0 ]; then
    echo -e "${GREEN}PASS: Fabric functioning correctly${RESET}"
else
    >&2 echo -e "${RED}FAIL: Fabric not functioning correctly/completely${RESET}"
    exit 1
fi
