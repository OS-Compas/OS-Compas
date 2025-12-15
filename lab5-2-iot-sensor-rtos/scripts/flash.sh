#!/bin/bash

# STM32固件烧录脚本
# 支持OpenOCD和ST-Link CLI

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/../build"
FIRMWARE="$BUILD_DIR/rtthread.bin"
HEX_FILE="$BUILD_DIR/rtthread.hex"

# 默认使用OpenOCD
TOOL="openocd"
CHIP="stm32f103c8"
INTERFACE="stlink"

# 检查固件文件
if [ ! -f "$FIRMWARE" ] && [ ! -f "$HEX_FILE" ]; then
    echo "Error: Firmware file not found in $BUILD_DIR"
    echo "Please run build.sh first"
    exit 1
fi

# 选择烧录文件
if [ -f "$FIRMWARE" ]; then
    FILE_TO_FLASH="$FIRMWARE"
    FORMAT="bin"
    ADDRESS="0x08000000"
elif [ -f "$HEX_FILE" ]; then
    FILE_TO_FLASH="$HEX_FILE"
    FORMAT="ihex"
    ADDRESS=""
fi

echo "========================================"
echo "STM32 Firmware Flashing Tool"
echo "Chip: $CHIP"
echo "File: $(basename $FILE_TO_FLASH)"
echo "========================================"

# 检查烧录工具
check_tool() {
    case $1 in
        openocd)
            command -v openocd >/dev/null 2>&1
            ;;
        stlink)
            command -v ST-LINK_CLI >/dev/null 2>&1
            ;;
        *)
            return 1
            ;;
    esac
}

# 选择可用的工具
if ! check_tool $TOOL; then
    echo "Warning: $TOOL not found, trying alternatives..."
    
    if check_tool "stlink"; then
        TOOL="stlink"
        echo "Using ST-LINK CLI"
    elif check_tool "openocd"; then
        TOOL="openocd"
        echo "Using OpenOCD"
    else
        echo "Error: No flashing tool found!"
        echo "Please install OpenOCD or ST-Link CLI"
        exit 1
    fi
fi

# 烧录函数
flash_openocd() {
    echo -e "\nFlashing with OpenOCD..."
    
    openocd -f interface/$INTERFACE.cfg \
            -f target/stm32f1x.cfg \
            -c "init" \
            -c "reset halt" \
            -c "flash write_image erase $FILE_TO_FLASH $ADDRESS" \
            -c "reset run" \
            -c "exit"
    
    if [ $? -eq 0 ]; then
        echo "Flash successful!"
    else
        echo "Flash failed!"
        return 1
    fi
}

flash_stlink() {
    echo -e "\nFlashing with ST-LINK CLI..."
    
    if [ "$FORMAT" = "bin" ]; then
        ST-LINK_CLI -c SWD FREQ=4000 -P "$FILE_TO_FLASH" $ADDRESS -V -Run
    else
        ST-LINK_CLI -c SWD FREQ=4000 -P "$FILE_TO_FLASH" -V -Run
    fi
    
    if [ $? -eq 0 ]; then
        echo "Flash successful!"
    else
        echo "Flash failed!"
        return 1
    fi
}

# 擦除芯片
erase_chip() {
    echo -e "\nErasing chip..."
    
    case $TOOL in
        openocd)
            openocd -f interface/$INTERFACE.cfg \
                    -f target/stm32f1x.cfg \
                    -c "init" \
                    -c "reset halt" \
                    -c "flash erase_sector 0 0 last" \
                    -c "exit"
            ;;
        stlink)
            ST-LINK_CLI -c SWD FREQ=4000 -ME
            ;;
    esac
}

# 验证固件
verify_firmware() {
    echo -e "\nVerifying firmware..."
    
    case $TOOL in
        openocd)
            openocd -f interface/$INTERFACE.cfg \
                    -f target/stm32f1x.cfg \
                    -c "init" \
                    -c "reset halt" \
                    -c "verify_image $FILE_TO_FLASH $ADDRESS" \
                    -c "exit"
            ;;
        stlink)
            ST-LINK_CLI -c SWD FREQ=4000 -V "$FILE_TO_FLASH" $ADDRESS
            ;;
    esac
}

# 显示芯片信息
chip_info() {
    echo -e "\nChip information:"
    
    case $TOOL in
        openocd)
            openocd -f interface/$INTERFACE.cfg \
                    -f target/stm32f1x.cfg \
                    -c "init" \
                    -c "flash info 0" \
                    -c "exit" 2>/dev/null | grep -A5 "Device"
            ;;
        stlink)
            ST-LINK_CLI -c SWD FREQ=4000 -List
            ;;
    esac
}

# 主菜单
show_menu() {
    echo -e "\nSelect operation:"
    echo "1. Flash firmware (erase + write + verify)"
    echo "2. Erase chip only"
    echo "3. Verify firmware"
    echo "4. Chip information"
    echo "5. Exit"
    echo -n "Choice [1-5]: "
}

# 处理用户选择
while true; do
    show_menu
    read choice
    
    case $choice in
        1)
            erase_chip
            case $TOOL in
                openocd) flash_openocd ;;
                stlink) flash_stlink ;;
            esac
            verify_firmware
            ;;
        2)
            erase_chip
            ;;
        3)
            verify_firmware
            ;;
        4)
            chip_info
            ;;
        5)
            echo "Goodbye!"
            exit 0
            ;;
        *)
            echo "Invalid choice!"
            ;;
    esac
    
    echo -e "\nPress Enter to continue..."
    read dummy
done