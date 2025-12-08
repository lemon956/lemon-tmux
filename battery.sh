#!/bin/bash
# 跨平台电池获取脚本
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

get_battery_windows() {
    # Windows 方法1: 使用 wmic
    if command -v wmic >/dev/null 2>&1; then
        battery=$(wmic path Win32_Battery get EstimatedChargeRemaining /value 2>/dev/null | grep -o '[0-9]*' | head -1)
        status=$(wmic path Win32_Battery get BatteryStatus /value 2>/dev/null | grep -o '[0-9]*' | head -1)
    fi
    
    # Windows 方法2: 使用 PowerShell (如果wmic失败)
    if [ -z "$battery" ] && command -v powershell.exe >/dev/null 2>&1; then
        battery=$(powershell.exe -Command "Get-WmiObject -Class Win32_Battery | Select-Object -ExpandProperty EstimatedChargeRemaining" 2>/dev/null | tr -d '\r')
        status=$(powershell.exe -Command "Get-WmiObject -Class Win32_Battery | Select-Object -ExpandProperty BatteryStatus" 2>/dev/null | tr -d '\r')
    fi
    
    if [ -n "$battery" ]; then
        # BatteryStatus: 1=其他, 2=充电中, 3=未充电, 4=电量不足, 5=电量严重不足
        if [ "$status" = "2" ]; then
            echo "⚡${battery}%"
        elif [ "$battery" -le 20 ]; then
            echo "🪫${battery}%"
        else
            echo "🔋${battery}%"
        fi
    else
        echo "⚡Endless Energy"
    fi
}

get_battery_macos() {
    # macOS 方法1: 使用 pmset
    if command -v pmset >/dev/null 2>&1; then
        battery_info=$(pmset -g batt 2>/dev/null)
        battery=$(echo "$battery_info" | grep -o '[0-9]*%' | head -1 | tr -d '%')
        status=$(echo "$battery_info" | grep -o 'charging\|discharging\|charged' | head -1)
    fi
    
    # macOS 方法2: 使用 system_profiler (备用)
    if [ -z "$battery" ] && command -v system_profiler >/dev/null 2>&1; then
        battery_info=$(system_profiler SPPowerDataType 2>/dev/null)
        battery=$(echo "$battery_info" | grep "State of Charge" | awk '{print $4}' | tr -d '%')
    fi
    
    if [ -n "$battery" ]; then
        if [ "$status" = "charging" ]; then
            echo "⚡${battery}%"
        elif [ "$battery" -le 20 ]; then
            echo "🪫${battery}%"
        else
            echo "🔋${battery}%"
        fi
    else
        echo "⚡Endless Energy"
    fi
}

get_battery_termux() {
    # Termux 方法1: 使用 termux-api
    if command -v termux-battery-status >/dev/null 2>&1; then
        info=$(termux-battery-status 2>/dev/null)
        battery=$(echo "$info" | grep percentage | cut -d':' -f2 | tr -d ' ,"')
        status=$(echo "$info" | grep status | cut -d':' -f2 | tr -d ' ,"')
    fi
    
    # Termux 方法2: 使用 dumpsys (备用)
    if [ -z "$battery" ] && command -v dumpsys >/dev/null 2>&1; then
        battery=$(dumpsys battery 2>/dev/null | grep level | cut -d':' -f2 | tr -d ' ')
        status=$(dumpsys battery 2>/dev/null | grep status | cut -d':' -f2 | tr -d ' ')
    fi
    
    if [ -n "$battery" ]; then
        # 状态码: 1=未知, 2=充电中, 3=未充电, 4=未充电, 5=充满
        if [ "$status" = "Charging" ] || [ "$status" = "CHARGING" ] || [ "$status" = "2" ]; then
            echo "⚡${battery}%"
        elif [ "$battery" -le 20 ]; then
            echo "🪫${battery}%"
        else
            echo "🔋${battery}%"
        fi
    else
        echo "⚡Endless Energy"
    fi
}

get_battery_linux() {
    # Linux 方法1: 使用 acpi
    if command -v acpi >/dev/null 2>&1; then
        battery_info=$(acpi -b 2>/dev/null | head -1)
        battery=$(echo "$battery_info" | grep -o '[0-9]*%' | head -1 | tr -d '%')
        status=$(echo "$battery_info" | grep -o 'Charging\|Discharging\|Full' | head -1)
    fi
    
    # Linux 方法2: 使用系统文件
    if [ -z "$battery" ]; then
        for path in /sys/class/power_supply/BAT*/capacity \
                    /sys/class/power_supply/battery/capacity \
                    /sys/class/power_supply/Battery/capacity; do
            if [ -f "$path" ]; then
                battery=$(cat "$path" 2>/dev/null)
                status_path=$(dirname "$path")/status
                if [ -f "$status_path" ]; then
                    status=$(cat "$status_path" 2>/dev/null)
                fi
                break
            fi
        done
    fi
    
    # Linux 方法3: 使用 upower
    if [ -z "$battery" ] && command -v upower >/dev/null 2>&1; then
        battery_device=$(upower -e | grep 'BAT' | head -1)
        if [ -n "$battery_device" ]; then
            battery_info=$(upower -i "$battery_device" 2>/dev/null)
            battery=$(echo "$battery_info" | grep percentage | awk '{print $2}' | tr -d '%')
            status=$(echo "$battery_info" | grep state | awk '{print $2}')
        fi
    fi
    
    if [ -n "$battery" ]; then
        if [ "$status" = "Charging" ] || [ "$status" = "charging" ]; then
            echo "⚡${battery}%"
        elif [ "$battery" -le 20 ]; then
            echo "🪫${battery}%"
        else
            echo "🔋${battery}%"
        fi
    else
        echo "⚡Endless Energy"
    fi
}

get_battery_wsl() {
    # WSL中通过PowerShell获取Windows电池信息
    if command -v powershell.exe >/dev/null 2>&1; then
        battery=$(powershell.exe -Command "(Get-WmiObject -Class Win32_Battery).EstimatedChargeRemaining" 2>/dev/null | tr -d '\r\n')
        status=$(powershell.exe -Command "(Get-WmiObject -Class Win32_Battery).BatteryStatus" 2>/dev/null | tr -d '\r\n')
        
        if [ -n "$battery" ]; then
            if [ "$status" = "2" ]; then
                echo "⚡${battery}%"
            elif [ "$battery" -le 20 ]; then
                echo "🪫${battery}%"
            else
                echo "🔋${battery}%"
            fi
        else
            echo "⚡Endless Energy"
        fi
    else
        echo "⚡Endless Energy"
    fi
}

# 主函数
get_battery_info() {
    os=$(detect_os)
    
    case "$os" in
        "windows")
            get_battery_windows
            ;;
        "macos")
            get_battery_macos
            ;;
        "termux")
            get_battery_termux
            ;;
        "linux")
            get_battery_linux
            ;;
        "wsl")
            get_battery_wsl
            ;;
        *)
            echo "⚡Endless Energy"
            ;;
    esac
}

# 如果脚本被直接执行，则运行主函数
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    get_battery_info
fi