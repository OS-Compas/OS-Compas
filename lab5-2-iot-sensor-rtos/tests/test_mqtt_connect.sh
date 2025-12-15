#!/bin/bash

# MQTT连接测试脚本
# 测试与MQTT代理服务器的连接

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/.."
TOOLS_DIR="$PROJECT_DIR/tools"

echo "========================================"
echo "MQTT Connection Test Script"
echo "========================================"

# 检查Python环境
if ! command -v python3 >/dev/null 2>&1; then
    echo "Error: python3 not found"
    exit 1
fi

# 检查paho-mqtt
if ! python3 -c "import paho.mqtt.client" 2>/dev/null; then
    echo "Installing paho-mqtt..."
    pip3 install paho-mqtt
fi

# 测试配置
BROKERS=(
    "test.mosquitto.org:1883"
    "broker.hivemq.com:1883"
    "mqtt.eclipseprojects.io:1883"
)

# 测试函数
test_mqtt_broker() {
    local broker=$1
    local host=${broker%:*}
    local port=${broker#*:}
    
    echo -e "\nTesting MQTT broker: $host:$port"
    
    # 创建Python测试脚本
    cat > /tmp/test_mqtt.py << EOF
import paho.mqtt.client as mqtt
import time
import sys

host = "$host"
port = $port
timeout = 5

def on_connect(client, userdata, flags, rc):
    if rc == 0:
        print("    ✅ Connected successfully")
        client.disconnect()
    else:
        print(f"    ❌ Connection failed (code: {rc})")
    client.loop_stop()

def on_disconnect(client, userdata, rc):
    pass

try:
    client = mqtt.Client()
    client.on_connect = on_connect
    client.on_disconnect = on_disconnect
    
    client.connect_async(host, port, 60)
    client.loop_start()
    
    # 等待连接完成
    time.sleep(timeout)
    
    if client.is_connected():
        client.disconnect()
    else:
        print("    ⏱️  Connection timeout")
        
except Exception as e:
    print(f"    ❌ Error: {e}")
    
sys.exit(0)
EOF
    
    # 运行测试
    timeout 10 python3 /tmp/test_mqtt.py
    local result=$?
    
    # 清理
    rm -f /tmp/test_mqtt.py
    
    return $result
}

# 主测试流程
echo "Starting MQTT broker connectivity tests..."
echo "This will test multiple public MQTT brokers"
echo ""

total_tests=${#BROKERS[@]}
passed_tests=0

for broker in "${BROKERS[@]}"; do
    if test_mqtt_broker "$broker"; then
        ((passed_tests++))
    fi
    sleep 1  # 避免频繁连接
done

# 测试结果
echo -e "\n========================================"
echo "Test Summary"
echo "========================================"
echo "Total brokers tested: $total_tests"
echo "Successful connections: $passed_tests"

if [ $passed_tests -eq $total_tests ]; then
    echo -e "\n✅ All MQTT brokers are accessible!"
    echo "Your network connection is working properly."
    exit 0
elif [ $passed_tests -gt 0 ]; then
    echo -e "\n⚠️  Some MQTT brokers are accessible."
    echo "Your firewall or network may be blocking some connections."
    exit 1
else
    echo -e "\n❌ No MQTT brokers are accessible!"
    echo "Please check your network connection and firewall settings."
    exit 1
fi

# 额外的功能测试
echo -e "\n========================================"
echo "Additional Functionality Tests"
echo "========================================"

# 测试发布/订阅功能
echo -e "\nTesting publish/subscribe functionality..."

cat > /tmp/test_pubsub.py << 'EOF'
import paho.mqtt.client as mqtt
import time
import json

broker = "test.mosquitto.org"
port = 1883
topic = "lab/iot/test"
message_count = 0

def on_connect(client, userdata, flags, rc):
    if rc == 0:
        print("    Connected to broker")
        client.subscribe(topic)
    else:
        print(f"    Connection failed: {rc}")

def on_message(client, userdata, msg):
    global message_count
    message_count += 1
    print(f"    Received message #{message_count}")
    
    if message_count >= 3:
        client.disconnect()

def on_publish(client, userdata, mid):
    print(f"    Message published: {mid}")

def run_test():
    client = mqtt.Client()
    client.on_connect = on_connect
    client.on_message = on_message
    client.on_publish = on_publish
    
    client.connect(broker, port, 60)
    client.loop_start()
    
    # 发布测试消息
    for i in range(3):
        payload = json.dumps({
            "test": "message",
            "number": i + 1,
            "timestamp": time.time()
        })
        client.publish(topic, payload)
        time.sleep(1)
    
    # 等待消息接收
    timeout = 10
    start_time = time.time()
    
    while message_count < 3 and time.time() - start_time < timeout:
        time.sleep(0.1)
    
    client.loop_stop()
    
    if message_count == 3:
        print("    ✅ Publish/Subscribe test passed")
        return True
    else:
        print(f"    ❌ Test failed (received {message_count}/3 messages)")
        return False

if run_test():
    exit(0)
else:
    exit(1)
EOF

echo "Running publish/subscribe test..."
if python3 /tmp/test_pubsub.py; then
    echo "✅ Publish/Subscribe functionality is working"
else
    echo "❌ Publish/Subscribe test failed"
fi

rm -f /tmp/test_pubsub.py

echo -e "\nAll tests completed!"