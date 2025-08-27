#!/bin/bash

if [ -z "$1" ]; then
  echo "Uso: $0 <PID_DO_CHROME>"
  exit 1
fi

PID=$1
CSV_FILE="chrome_metrics.csv"

# Cabeçalho do CSV
echo "timestamp,pid,cpu_percent,cpu_num,read_kBps,write_kBps,ram_livre_kB,ram_usada_kB,ram_buffer_kB,ram_cache_kB" > "$CSV_FILE"

# Captura inicial para calcular deltas depois
prev_read_io=$(grep "^read_bytes:" /proc/$PID/io | awk '{print $2}')
prev_write_io=$(grep "^write_bytes:" /proc/$PID/io | awk '{print $2}')

while true; do
  timestamp=$(date "+%Y-%m-%d %H:%M:%S")

  # CPU (usando pidstat)
  pidstat_out=$(pidstat -h -p $PID 1 1 | grep -v "Linux" | grep -E "^[[:space:]]*$PID")
  cpu_percent=$(echo "$pidstat_out" | awk '{print $7}')
  cpu_num=$(ps -o psr= -p $PID | tr -d ' ')

  # IO atual
  read_io=$(grep "^read_bytes:" /proc/$PID/io | awk '{print $2}')
  write_io=$(grep "^write_bytes:" /proc/$PID/io | awk '{print $2}')

  # Calcular diferenças com segurança usando bc
  delta_read=$(echo "$read_io - $prev_read_io" | bc)
  delta_write=$(echo "$write_io - $prev_write_io" | bc)

  if [[ $(echo "$delta_read >= 0" | bc) -eq 1 ]]; then
    read_kBps=$(echo "scale=2; $delta_read / 1024 / 10" | bc)
  else
    read_kBps=0
  fi

  if [[ $(echo "$delta_write >= 0" | bc) -eq 1 ]]; then
    write_kBps=$(echo "scale=2; $delta_write / 1024 / 10" | bc)
  else
    write_kBps=0
  fi

  # Memória
  mem_out=$(free -k | grep Mem)
  ram_total_kB=$(echo $mem_out | awk '{print $2}')
  ram_livre_kB=$(echo $mem_out | awk '{print $4}')
  ram_buffer_kB=$(echo $mem_out | awk '{print $6}')
  ram_cache_kB=$(echo $mem_out | awk '{print $7}')
  ram_usada_kB=$(echo "$ram_total_kB - $ram_livre_kB - $ram_buffer_kB - $ram_cache_kB" | bc)

  # Escreve linha no CSV
  echo "$timestamp,$PID,$cpu_percent,$cpu_num,$read_kBps,$write_kBps,$ram_livre_kB,$ram_usada_kB,$ram_buffer_kB,$ram_cache_kB" >> "$CSV_FILE"

  # Atualiza valores anteriores
  prev_read_io=$read_io
  prev_write_io=$write_io

  sleep 10
done

