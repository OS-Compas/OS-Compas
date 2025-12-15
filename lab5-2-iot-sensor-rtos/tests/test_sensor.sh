#!/bin/bash

# 传感器测试脚本
# 用于测试DHT11传感器功能

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/.."
BUILD_DIR="$PROJECT_DIR/build"

echo "========================================"
echo "DHT11 Sensor Test Script"
echo "========================================"

# 检查测试程序
TEST_PROGRAM="$BUILD_DIR/sensor_test"
if [ ! -f "$TEST_PROGRAM" ]; then
    echo "Building sensor test program..."
    
    cat > /tmp/sensor_test.c << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <wiringPi.h>

#define DHT_PIN 7  // GPIO4

int read_dht_data(float *temperature, float *humidity) {
    int data[5] = {0, 0, 0, 0, 0};
    uint8_t laststate = HIGH;
    uint8_t counter = 0;
    uint8_t j = 0, i;
    
    // 发送开始信号
    pinMode(DHT_PIN, OUTPUT);
    digitalWrite(DHT_PIN, LOW);
    delay(18);
    digitalWrite(DHT_PIN, HIGH);
    delayMicroseconds(40);
    pinMode(DHT_PIN, INPUT);
    
    // 读取数据
    for (i = 0; i < 85; i++) {
        counter = 0;
        while (digitalRead(DHT_PIN) == laststate) {
            counter++;
            delayMicroseconds(1);
            if (counter == 255) break;
        }
        laststate = digitalRead(DHT_PIN);
        
        if (counter == 255) break;
        
        if ((i >= 4) && (i % 2 == 0)) {
            data[j / 8] <<= 1;
            if (counter > 16) data[j / 8] |= 1;
            j++;
        }
    }
    
    // 校验数据
    if ((j >= 40) && 
        (data[4] == ((data[0] + data[1] + data[2] + data[3]) & 0xFF))) {
        *humidity = (float)data[0];
        *temperature = (float)data[2];
        return 0;
    }
    
    return -1;
}

int main() {
    printf("DHT11 Sensor Test\n");
    printf("=================\n");
    
    if (wiringPiSetup() == -1) {
        printf("wiringPi setup failed!\n");
        return 1;
    }
    
    printf("Initializing DHT11 on GPIO4...\n");
    
    int test_count = 10;
    int success_count = 0;
    
    for (int i = 0; i < test_count; i++) {
        float temp, humi;
        
        printf("\nTest %d/%d:\n", i + 1, test_count);
        
        if (read_dht_data(&temp, &humi) == 0) {
            printf("  Temperature: %.1f°C\n", temp);
            printf("  Humidity: %.1f%%\n", humi);
            success_count++;
        } else {
            printf("  Read failed!\n");
        }
        
        if (i < test_count - 1) {
            sleep(2);  // DHT11需要至少2秒间隔
        }
    }
    
    printf("\nTest Summary:\n");
    printf("  Total tests: %d\n", test_count);
    printf("  Successful: %d\n", success_count);
    printf("  Success rate: %.1f%%\n", 
           (success_count * 100.0) / test_count);
    
    if (success_count == test_count) {
        printf("\n✅ All tests passed!\n");
        return 0;
    } else {
        printf("\n❌ Some tests failed!\n");
        return 1;
    }
}
EOF
    
    # 编译测试程序（树莓派环境）
    if command -v gcc >/dev/null 2>&1; then
        gcc -o "$TEST_PROGRAM" /tmp/sensor_test.c -lwiringPi -lm
        if [ $? -ne 0 ]; then
            echo "Compilation failed. Make sure wiringPi is installed."
            echo "On Raspberry Pi: sudo apt install wiringpi"
            exit 1
        fi
    else
        echo "gcc not found. Cannot compile test program."
        exit 1
    fi
fi

# 运行测试
echo "Starting sensor tests..."
echo "Make sure DHT11 is connected to GPIO4 (wiringPi pin 7)"
echo ""

if [ ! -f "$TEST_PROGRAM" ]; then
    echo "Test program not found: $TEST_PROGRAM"
    exit 1
fi

# 检查是否需要sudo
if [ "$EUID" -ne 0 ]; then
    echo "Note: GPIO access requires root privileges"
    echo "Trying with sudo..."
    sudo "$TEST_PROGRAM"
else
    "$TEST_PROGRAM"
fi

# 清理
rm -f /tmp/sensor_test.c

echo -e "\nTest completed!"