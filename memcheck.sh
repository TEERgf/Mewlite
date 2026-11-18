#!/usr/bin/env bash
# Show where your RAM goes (real usage, grouped by program).
echo "== System =="
free -h | awk 'NR<=2'
echo
echo "== zram =="
zramctl 2>/dev/null || echo "zram not active"
echo
echo "== Top 15 programs by RAM (RSS, summed per name) =="
ps -eo rss=,comm= | awk '{m[$2]+=$1} END {for (p in m) printf "%8.1f MB  %s\n", m[p]/1024, p}' | sort -rn | head -15
echo
echo "== NVIDIA dGPU power state (Optimus: 'suspended' = sleeping, good) =="
for d in /sys/bus/pci/devices/*; do
  [[ $(cat "$d/vendor" 2>/dev/null) == 0x10de && $(cat "$d/class") == 0x03* ]] && \
    echo "$(basename "$d"): $(cat "$d/power/runtime_status")"
done
