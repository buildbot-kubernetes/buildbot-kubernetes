#!/usr/bin/env bash

vercomp() {
    local IFS=.
    local i ver1=($1) ver2=($2)
    for ((i=0; i<${#ver2[@]}; i++))
    do
        if [[ -z ${ver2[i]} ]]
        then
            return 0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]}))
        then
            return 0
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]}))
        then
            return 1
        fi
    done
    return 0
}

if ! vercomp "$1" "$2"; then
    echo "Version '$1' can't be lower than previous version '$2'"
    exit 1
fi
