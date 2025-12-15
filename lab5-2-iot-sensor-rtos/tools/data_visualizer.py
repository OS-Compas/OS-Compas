#!/usr/bin/env python3
"""
数据可视化脚本
用于显示从MQTT接收到的传感器数据
"""

import paho.mqtt.client as mqtt
import json
import matplotlib.pyplot as plt
import matplotlib.animation as animation
from datetime import datetime
import time
from collections import deque
import argparse

# 全局变量
data_buffer = {
    'temperature': deque(maxlen=100),
    'humidity': deque(maxlen=100),
    'timestamps': deque(maxlen=100)
}

# MQTT配置
BROKER = "test.mosquitto.org"
PORT = 1883
TOPIC = "lab/iot/sensor/#"
CLIENT_ID = f"visualizer_{int(time.time())}"

# 初始化图表
fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(12, 8))
fig.suptitle('IoT Sensor Data Visualization', fontsize=16)

# 温度曲线
temp_line, = ax1.plot([], [], 'r-', linewidth=2, label='Temperature')
ax1.set_ylabel('Temperature (°C)', fontsize=12)
ax1.set_ylim(0, 50)
ax1.grid(True, alpha=0.3)
ax1.legend(loc='upper left')
ax1.set_title('Real-time Temperature')

# 湿度曲线
humi_line, = ax2.plot([], [], 'b-', linewidth=2, label='Humidity')
ax2.set_xlabel('Time', fontsize=12)
ax2.set_ylabel('Humidity (%)', fontsize=12)
ax2.set_ylim(0, 100)
ax2.grid(True, alpha=0.3)
ax2.legend(loc='upper left')
ax2.set_title('Real-time Humidity')

def on_connect(client, userdata, flags, rc):
    """MQTT连接回调"""
    if rc == 0:
        print(f"Connected to MQTT broker: {BROKER}:{PORT}")
        client.subscribe(TOPIC)
        print(f"Subscribed to topic: {TOPIC}")
    else:
        print(f"Failed to connect, return code: {rc}")

def on_message(client, userdata, msg):
    """MQTT消息回调"""
    try:
        payload = msg.payload.decode()
        data = json.loads(payload)
        
        # 提取数据
        temp = data.get('temp', 0)
        humi = data.get('humi', 0)
        timestamp = data.get('time', time.time())
        
        # 添加到缓冲区
        data_buffer['temperature'].append(temp)
        data_buffer['humidity'].append(humi)
        data_buffer['timestamps'].append(
            datetime.fromtimestamp(timestamp).strftime('%H:%M:%S')
        )
        
        print(f"Received: {msg.topic}")
        print(f"  Temperature: {temp}°C, Humidity: {humi}%")
        
    except Exception as e:
        print(f"Error parsing message: {e}")

def update_plot(frame):
    """更新图表"""
    if len(data_buffer['timestamps']) > 0:
        # 更新温度图表
        temp_line.set_data(
            range(len(data_buffer['temperature'])),
            list(data_buffer['temperature'])
        )
        ax1.relim()
        ax1.autoscale_view()
        
        # 更新湿度图表
        humi_line.set_data(
            range(len(data_buffer['humidity'])),
            list(data_buffer['humidity'])
        )
        ax2.relim()
        ax2.autoscale_view()
        
        # 设置X轴标签
        if len(data_buffer['timestamps']) > 10:
            indices = list(range(len(data_buffer['timestamps'])))
            step = max(1, len(indices) // 10)
            visible_indices = indices[::step]
            visible_labels = [data_buffer['timestamps'][i] 
                            for i in visible_indices]
            
            ax2.set_xticks(visible_indices)
            ax2.set_xticklabels(visible_labels, rotation=45)
        else:
            ax2.set_xticks(range(len(data_buffer['timestamps'])))
            ax2.set_xticklabels(data_buffer['timestamps'], rotation=45)
    
    return temp_line, humi_line

def main():
    parser = argparse.ArgumentParser(description='IoT数据可视化工具')
    parser.add_argument('-b', '--broker', default=BROKER,
                       help='MQTT代理地址')
    parser.add_argument('-p', '--port', type=int, default=PORT,
                       help='MQTT代理端口')
    parser.add_argument('-t', '--topic', default=TOPIC,
                       help='订阅的主题')
    parser.add_argument('-s', '--save', action='store_true',
                       help='保存数据到文件')
    
    args = parser.parse_args()
    
    # 创建MQTT客户端
    client = mqtt.Client(CLIENT_ID)
    client.on_connect = on_connect
    client.on_message = on_message
    
    try:
        # 连接MQTT
        print(f"Connecting to {args.broker}:{args.port}...")
        client.connect(args.broker, args.port, 60)
        client.loop_start()
        
        # 设置动画
        ani = animation.FuncAnimation(
            fig, update_plot, interval=1000,
            blit=True, cache_frame_data=False
        )
        
        # 调整布局
        plt.tight_layout()
        
        # 显示图表
        print("\nDisplaying real-time data visualization...")
        print("Close the window to exit.")
        plt.show()
        
    except KeyboardInterrupt:
        print("\nInterrupted by user")
    except Exception as e:
        print(f"Error: {e}")
    finally:
        # 清理
        if 'client' in locals():
            client.loop_stop()
            client.disconnect()
            print("Disconnected from MQTT broker")
        
        # 保存数据
        if args.save and len(data_buffer['timestamps']) > 0:
            filename = f"sensor_data_{int(time.time())}.json"
            with open(filename, 'w') as f:
                save_data = {
                    'temperature': list(data_buffer['temperature']),
                    'humidity': list(data_buffer['humidity']),
                    'timestamps': list(data_buffer['timestamps'])
                }
                json.dump(save_data, f, indent=2)
            print(f"Data saved to {filename}")

if __name__ == "__main__":
    main()