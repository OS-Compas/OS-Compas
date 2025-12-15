#!/usr/bin/env python3
"""
MQTT测试发布脚本
用于测试IoT数据采集器的MQTT功能
"""

import paho.mqtt.client as mqtt
import json
import time
import random
import argparse
from datetime import datetime

# MQTT配置
BROKER = "test.mosquitto.org"
PORT = 1883
TOPIC_PREFIX = "lab/iot/sensor"
CLIENT_ID = f"mqtt_test_{random.randint(1000, 9999)}"

# 回调函数
def on_connect(client, userdata, flags, rc):
    """连接回调"""
    if rc == 0:
        print(f"Connected to MQTT Broker: {BROKER}:{PORT}")
        print(f"Client ID: {CLIENT_ID}")
    else:
        print(f"Failed to connect, return code: {rc}")

def on_publish(client, userdata, mid):
    """发布回调"""
    print(f"Message published: {mid}")

def on_message(client, userdata, msg):
    """消息回调"""
    print(f"Received message: {msg.topic} -> {msg.payload.decode()}")

def generate_sensor_data():
    """生成模拟传感器数据"""
    return {
        "temp": round(random.uniform(15.0, 35.0), 1),
        "humi": round(random.uniform(30.0, 80.0), 1),
        "time": int(time.time()),
        "device_id": "test_device_001",
        "location": "lab_room_101"
    }

def publish_single_message(client, topic, data, qos=0, retain=False):
    """发布单条消息"""
    payload = json.dumps(data, indent=2)
    result = client.publish(topic, payload, qos=qos, retain=retain)
    
    if result[0] == 0:
        print(f"Published to {topic}:")
        print(payload)
        return True
    else:
        print(f"Failed to publish to {topic}")
        return False

def subscribe_topic(client, topic, qos=0):
    """订阅主题"""
    result = client.subscribe(topic, qos=qos)
    if result[0] == 0:
        print(f"Subscribed to topic: {topic}")
        return True
    else:
        print(f"Failed to subscribe to {topic}")
        return False

def main():
    parser = argparse.ArgumentParser(description="MQTT测试工具")
    parser.add_argument("-m", "--mode", choices=["publish", "subscribe", "both"],
                       default="publish", help="运行模式")
    parser.add_argument("-t", "--topic", default=TOPIC_PREFIX,
                       help="MQTT主题")
    parser.add_argument("-c", "--count", type=int, default=10,
                       help="发布消息数量")
    parser.add_argument("-i", "--interval", type=float, default=2.0,
                       help="发布间隔（秒）")
    parser.add_argument("-q", "--qos", type=int, choices=[0, 1, 2], default=0,
                       help="QoS等级")
    parser.add_argument("-r", "--retain", action="store_true",
                       help="保留消息")
    
    args = parser.parse_args()
    
    # 创建MQTT客户端
    client = mqtt.Client(CLIENT_ID)
    client.on_connect = on_connect
    client.on_publish = on_publish
    client.on_message = on_message
    
    try:
        # 连接MQTT代理
        print(f"Connecting to {BROKER}:{PORT}...")
        client.connect(BROKER, PORT, 60)
        client.loop_start()
        
        time.sleep(1)  # 等待连接建立
        
        # 根据模式执行操作
        if args.mode in ["publish", "both"]:
            # 发布消息
            print(f"\nPublishing {args.count} messages to {args.topic}")
            print(f"Interval: {args.interval}s, QoS: {args.qos}")
            
            for i in range(args.count):
                # 生成传感器数据
                data = generate_sensor_data()
                data["sequence"] = i + 1
                
                # 发布到不同主题
                topics = [
                    f"{args.topic}/temperature",
                    f"{args.topic}/humidity",
                    f"{args.topic}/data"
                ]
                
                for topic in topics:
                    publish_single_message(
                        client, topic, data, 
                        qos=args.qos, retain=args.retain
                    )
                
                if i < args.count - 1:
                    time.sleep(args.interval)
        
        if args.mode in ["subscribe", "both"]:
            # 订阅主题
            topics = [
                f"{args.topic}/#",  # 订阅所有子主题
                f"{args.topic}/data",
                f"{args.topic}/status",
                f"{args.topic}/command"
            ]
            
            print(f"\nSubscribing to topics:")
            for topic in topics:
                subscribe_topic(client, topic, qos=args.qos)
            
            # 保持运行以接收消息
            print("\nWaiting for messages... (Press Ctrl+C to exit)")
            try:
                while True:
                    time.sleep(1)
            except KeyboardInterrupt:
                print("\nStopping subscription...")
        
        # 断开连接
        client.loop_stop()
        client.disconnect()
        print("\nDisconnected from MQTT broker")
        
    except KeyboardInterrupt:
        print("\nInterrupted by user")
    except Exception as e:
        print(f"Error: {e}")
    finally:
        if client.is_connected():
            client.disconnect()

if __name__ == "__main__":
    main()