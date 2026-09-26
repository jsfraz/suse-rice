#!/bin/sh
# RunCat: idle at <=5% CPU, otherwise five frames.
# Frame delay is linear from 250ms (0%) to 50ms (100%).
prev_active=0
prev_total=0
cpu=0
frame=0

read_cpu() {
    set -- $(awk '/^cpu / {print $2,$3,$4,$5,$6,$7,$8,$9; exit}' /proc/stat)
    user=$1
    nice=$2
    system=$3
    idle=$4
    iowait=$5
    irq=$6
    softirq=$7
    steal=$8
    active=$((user + nice + system))
    total=$((user + nice + system + idle + iowait + irq + softirq + steal))
    if [ "$prev_total" -ne 0 ]; then
        da=$((active - prev_active))
        dt=$((total - prev_total))
        if [ "$dt" -gt 0 ] && [ "$da" -ge 0 ]; then
            cpu=$((da * 100 / dt))
        fi
    fi
    prev_active=$active
    prev_total=$total
    if [ "$cpu" -lt 0 ]; then
        cpu=0
    fi
    if [ "$cpu" -gt 100 ]; then
        cpu=100
    fi
}

emit() {
    printf '{"text":"","tooltip":"%s%%","class":"%s"}\n' "$cpu" "$1"
}

read_cpu
sleep 0.2
read_cpu
last_cpu=$(date +%s)

while true; do
    now=$(date +%s)
    if [ $((now - last_cpu)) -ge 1 ]; then
        read_cpu
        last_cpu=$now
    fi
    if [ "$cpu" -le 5 ]; then
        emit idle
        sleep 0.25
    else
        emit "frame-$frame"
        frame=$(((frame + 1) % 5))
        ms=$((250 - cpu * 2))
        if [ "$ms" -lt 50 ]; then
            ms=50
        fi
        sleep "$(awk -v ms="$ms" 'BEGIN{printf "%.3f", ms/1000}')"
    fi
done
