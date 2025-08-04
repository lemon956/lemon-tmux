#!/bin/bash
# 简化版系统资源监控脚本 - 只返回图标和数值
# 支持: Windows (Git Bash/WSL), macOS, Linux, Android (Termux)

detect_os() {
    if [ -n "$TERMUX_VERSION" ]; then
        echo "termux"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
        echo "windows"
    elif grep -q Microsoft /proc/version 2>/dev/null; then
        echo "wsl"
    else
        echo "unknown"
    fi
}

get_cpu_usage_linux() {
    # 方法1: 使用 top
    if command -v top >/dev/null 2>&1; then
        cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | awk -F'%' '{print $1}' 2>/dev/null)
        if [ -n "$cpu" ]; then
            echo "$cpu"
            return
        fi
    fi
    
    # 方法2: 使用 /proc/stat
    if [ -f /proc/stat ]; then
        cpu=$(awk '/^cpu / {usage=($2+$4)*100/($2+$3+$4+$5)} END {print usage}' /proc/stat 2>/dev/null)
        if [ -n "$cpu" ]; then
            printf "%.1f" "$cpu" 2>/dev/null || echo "0"
            return
        fi
    fi
    
    # 方法3: 使用 vmstat
    if command -v vmstat >/dev/null 2>&1; then
        cpu=$(vmstat 1 2 | tail -1 | awk '{print 100-$15}' 2>/dev/null)
        if [ -n "$cpu" ]; then
            echo "$cpu"
            return
        fi
    fi
    
    echo "0"
}

get_memory_usage_linux() {
    # 方法1: 使用 free
    if command -v free >/dev/null 2>&1; then
        mem=$(free | awk 'NR==2{printf "%.1f", $3*100/$2}' 2>/dev/null)
        if [ -n "$mem" ]; then
            echo "$mem"
            return
        fi
    fi
    
    # 方法2: 使用 /proc/meminfo
    if [ -f /proc/meminfo ]; then
        mem=$(awk '/MemTotal/{total=$2} /MemAvailable/{avail=$2} END{print (total-avail)*100/total}' /proc/meminfo 2>/dev/null)
        if [ -n "$mem" ]; then
            printf "%.1f" "$mem" 2>/dev/null || echo "0"
            return
        fi
    fi
    
    echo "0"
}

get_cpu_usage_macos() {
    # 方法1: 使用 top
    if command -v top >/dev/null 2>&1; then
        cpu=$(top -l 1 -s 0 | grep "CPU usage" | awk '{print $3}' | sed 's/%//' 2>/dev/null)
        if [ -n "$cpu" ]; then
            echo "$cpu"
            return
        fi
    fi
    
    # 方法2: 使用 iostat
    if command -v iostat >/dev/null 2>&1; then
        cpu=$(iostat -c 1 | awk 'NR==4 {print 100-$6}' 2>/dev/null)
        if [ -n "$cpu" ]; then
            echo "$cpu"
            return
        fi
    fi
    
    echo "0"
}

get_memory_usage_macos() {
    # 使用 vm_stat
    if command -v vm_stat >/dev/null 2>&1; then
        vm_stat_output=$(vm_stat)
        pages_free=$(echo "$vm_stat_output" | awk '/Pages free/ {print $3}' | tr -d '.')
        pages_active=$(echo "$vm_stat_output" | awk '/Pages active/ {print $3}' | tr -d '.')
        pages_inactive=$(echo "$vm_stat_output" | awk '/Pages inactive/ {print $3}' | tr -d '.')
        pages_speculative=$(echo "$vm_stat_output" | awk '/Pages speculative/ {print $3}' | tr -d '.')
        pages_wired=$(echo "$vm_stat_output" | awk '/Pages wired down/ {print $4}' | tr -d '.')
        
        if [ -n "$pages_free" ] && [ -n "$pages_active" ]; then
            total=$((pages_free + pages_active + pages_inactive + pages_speculative + pages_wired))
            used=$((pages_active + pages_inactive + pages_wired))
            mem=$(echo "scale=1; $used * 100 / $total" | bc 2>/dev/null)
            echo "$mem"
            return
        fi
    fi
    
    echo "0"
}

get_cpu_usage_windows() {
    # 使用 wmic
    if command -v wmic >/dev/null 2>&1; then
        cpu=$(wmic cpu get loadpercentage /value 2>/dev/null | grep -o '[0-9]*' | head -1)
        if [ -n "$cpu" ]; then
            echo "$cpu"
            return
        fi
    fi
    
    # 使用 PowerShell
    if command -v powershell.exe >/dev/null 2>&1; then
        cpu=$(powershell.exe -Command "Get-WmiObject -Class Win32_Processor | Measure-Object -Property LoadPercentage -Average | Select-Object -ExpandProperty Average" 2>/dev/null | tr -d '\r')
        if [ -n "$cpu" ]; then
            echo "$cpu"
            return
        fi
    fi
    
    echo "0"
}

get_memory_usage_windows() {
    # 使用 wmic
    if command -v wmic >/dev/null 2>&1; then
        total=$(wmic computersystem get TotalPhysicalMemory /value 2>/dev/null | grep -o '[0-9]*' | head -1)
        available=$(wmic OS get FreePhysicalMemory /value 2>/dev/null | grep -o '[0-9]*' | head -1)
        if [ -n "$total" ] && [ -n "$available" ]; then
            available_bytes=$((available * 1024))
            used_bytes=$((total - available_bytes))
            mem=$(echo "scale=1; $used_bytes * 100 / $total" | bc 2>/dev/null)
            echo "$mem"
            return
        fi
    fi
    
    # 使用 PowerShell
    if command -v powershell.exe >/dev/null 2>&1; then
        mem=$(powershell.exe -Command "\$os = Get-WmiObject -Class Win32_OperatingSystem; \$total = \$os.TotalVisibleMemorySize * 1024; \$free = \$os.FreePhysicalMemory * 1024; (\$total - \$free) * 100 / \$total" 2>/dev/null | tr -d '\r')
        if [ -n "$mem" ]; then
            printf "%.1f" "$mem" 2>/dev/null || echo "0"
            return
        fi
    fi
    
    echo "0"
}

get_cpu_usage_termux() {
    # 使用 top
    if command -v top >/dev/null 2>&1; then
        cpu=$(top -n 1 | grep "%cpu" | awk '{print $9}' | head -1 | sed 's/%//' 2>/dev/null)
        if [ -n "$cpu" ]; then
            echo "$cpu"
            return
        fi
    fi
    
    # 使用 /proc/stat
    if [ -f /proc/stat ]; then
        cpu=$(awk '/^cpu / {usage=($2+$4)*100/($2+$3+$4+$5)} END {print usage}' /proc/stat 2>/dev/null)
        if [ -n "$cpu" ]; then
            printf "%.1f" "$cpu" 2>/dev/null || echo "0"
            return
        fi
    fi
    
    echo "0"
}

get_memory_usage_termux() {
    # 使用 /proc/meminfo
    if [ -f /proc/meminfo ]; then
        mem=$(awk '/MemTotal/{total=$2} /MemAvailable/{avail=$2} END{print (total-avail)*100/total}' /proc/meminfo 2>/dev/null)
        if [ -n "$mem" ]; then
            printf "%.1f" "$mem" 2>/dev/null || echo "0"
            return
        fi
    fi
    
    echo "0"
}

# 获取系统资源使用率
get_system_usage() {
    os=$(detect_os)
    
    case "$os" in
        "linux")
            cpu=$(get_cpu_usage_linux)
            mem=$(get_memory_usage_linux)
            ;;
        "macos")
            cpu=$(get_cpu_usage_macos)
            mem=$(get_memory_usage_macos)
            ;;
        "windows")
            cpu=$(get_cpu_usage_windows)
            mem=$(get_memory_usage_windows)
            ;;
        "wsl")
            cpu=$(get_cpu_usage_linux)
            mem=$(get_memory_usage_linux)
            ;;
        "termux")
            cpu=$(get_cpu_usage_termux)
            mem=$(get_memory_usage_termux)
            ;;
        *)
            cpu="0"
            mem="0"
            ;;
    esac
    
    # 格式化输出，只返回图标和数值
    cpu_int=$(printf "%.0f" "$cpu" 2>/dev/null || echo "0")
    mem_int=$(printf "%.0f" "$mem" 2>/dev/null || echo "0")
    
    cpu_icon="💻"
    mem_icon="💾"
    
    echo "${cpu_icon}${cpu_int}% ${mem_icon}${mem_int}%"
}

# 如果脚本被直接执行，则运行主函数
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    get_system_usage
fi