#!/bin/sh
# Выводит метрики в формате "ключ значение" (по строке). Вызывается из services/SysStats.qml.
read -r _ u n s i io irq sirq st _ < /proc/stat
echo "cpu_total $((u+n+s+i+io+irq+sirq+st))"
echo "cpu_idle $((i+io))"

for h in /sys/class/hwmon/hwmon*; do
  case "$(cat "$h/name" 2>/dev/null)" in
    k10temp|coretemp|zenpower) echo "cpu_temp $(( $(cat "$h/temp1_input") / 1000 ))"; break ;;
  esac
done

awk '/^MemTotal/{t=$2} /^MemAvailable/{a=$2} END{print "ram_total " int(t/1024); print "ram_used " int((t-a)/1024)}' /proc/meminfo

if command -v nvidia-smi >/dev/null 2>&1; then
  nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null \
    | head -1 | awk -F', *' '{print "gpu_load " $1; print "gpu_temp " $2; print "vram_used " $3; print "vram_total " $4}'
else
  for d in /sys/class/drm/card*/device; do
    [ -r "$d/gpu_busy_percent" ] || continue
    echo "gpu_load $(cat "$d/gpu_busy_percent")"
    echo "vram_used $(( $(cat "$d/mem_info_vram_used") / 1048576 ))"
    echo "vram_total $(( $(cat "$d/mem_info_vram_total") / 1048576 ))"
    for t in "$d"/hwmon/hwmon*/temp1_input; do
      [ -r "$t" ] && echo "gpu_temp $(( $(cat "$t") / 1000 ))" && break
    done
    break
  done
fi
