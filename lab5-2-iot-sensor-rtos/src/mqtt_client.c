/**
 * mqtt_client.c - MQTT客户端实现
 * 基于Paho MQTT嵌入式客户端库
 */

#include <rtthread.h>
#include <rtdevice.h>
#include <stdio.h>
#include <string.h>
#include "mqtt_config.h"
#include "wifi_esp8266.h"
#include "mqtt_client.h"

/* MQTT客户端状态 */
typedef enum {
    MQTT_STATE_DISCONNECTED,
    MQTT_STATE_CONNECTING,
    MQTT_STATE_CONNECTED
} mqtt_state_t;

static mqtt_state_t mqtt_state = MQTT_STATE_DISCONNECTED;
static rt_mutex_t mqtt_mutex = RT_NULL;

/* MQTT报文类型 */
#define MQTT_MSG_CONNECT     0x10
#define MQTT_MSG_CONNACK     0x20
#define MQTT_MSG_PUBLISH     0x30
#define MQTT_MSG_PUBACK      0x40
#define MQTT_MSG_SUBSCRIBE   0x82
#define MQTT_MSG_SUBACK      0x90
#define MQTT_MSG_PINGREQ     0xC0
#define MQTT_MSG_PINGRESP    0xD0
#define MQTT_MSG_DISCONNECT  0xE0

/* 构造MQTT连接报文 */
static rt_size_t mqtt_build_connect_packet(char *buffer, const char *client_id) {
    char *p = buffer;
    rt_uint32_t remaining_len;
    
    /* 固定头部 */
    *p++ = MQTT_MSG_CONNECT;
    
    /* 剩余长度（先占位） */
    *p++ = 0;
    
    /* 协议名 */
    *p++ = 0; *p++ = 4;  /* 长度 */
    *p++ = 'M'; *p++ = 'Q'; *p++ = 'T'; *p++ = 'T';
    *p++ = 4;  /* 协议级别 3.1.1 */
    
    /* 连接标志 */
    *p++ = 0x02;  /* 清理会话 */
    
    /* 保持连接时间 */
    *p++ = (MQTT_KEEPALIVE >> 8) & 0xFF;
    *p++ = MQTT_KEEPALIVE & 0xFF;
    
    /* 客户端ID */
    rt_uint16_t client_id_len = rt_strlen(client_id);
    *p++ = (client_id_len >> 8) & 0xFF;
    *p++ = client_id_len & 0xFF;
    memcpy(p, client_id, client_id_len);
    p += client_id_len;
    
    /* 计算剩余长度 */
    remaining_len = (rt_uint32_t)(p - buffer - 2);
    
    /* 更新剩余长度字段 */
    buffer[1] = remaining_len & 0x7F;
    if (remaining_len > 127) {
        buffer[1] |= 0x80;
        buffer[1] = remaining_len & 0x7F;
        buffer[2] = (remaining_len >> 7) & 0x7F;
    }
    
    return (rt_size_t)(p - buffer);
}

/* 构造MQTT发布报文 */
static rt_size_t mqtt_build_publish_packet(char *buffer, 
                                          const char *topic, 
                                          const char *payload) {
    char *p = buffer;
    rt_uint32_t remaining_len;
    rt_uint16_t topic_len = rt_strlen(topic);
    rt_uint16_t payload_len = rt_strlen(payload);
    
    /* 固定头部 */
    *p++ = MQTT_MSG_PUBLISH;
    
    /* 剩余长度（先占位） */
    *p++ = 0;
    
    /* 主题名 */
    *p++ = (topic_len >> 8) & 0xFF;
    *p++ = topic_len & 0xFF;
    memcpy(p, topic, topic_len);
    p += topic_len;
    
    /* 报文标识符（QoS 0不需要） */
    
    /* 有效载荷 */
    memcpy(p, payload, payload_len);
    p += payload_len;
    
    /* 计算剩余长度 */
    remaining_len = (rt_uint32_t)(p - buffer - 2);
    
    /* 更新剩余长度字段 */
    buffer[1] = remaining_len & 0x7F;
    if (remaining_len > 127) {
        buffer[1] |= 0x80;
        buffer[2] = (remaining_len >> 7) & 0x7F;
    }
    
    return (rt_size_t)(p - buffer);
}

/* 发送MQTT报文到服务器 */
static rt_err_t mqtt_send_packet(const char *packet, rt_size_t length) {
    char tcp_buffer[1024];
    rt_size_t tcp_len;
    
    /* 构造TCP数据 */
    rt_snprintf(tcp_buffer, sizeof(tcp_buffer), 
               "AT+CIPSEND=%d\r\n", length + 2);
    
    /* 通过WiFi发送 */
    return wifi_send_tcp(MQTT_BROKER_HOST, MQTT_BROKER_PORT, 
                        packet, length);
}

/* 连接到MQTT代理服务器 */
static rt_err_t mqtt_connect_to_broker(void) {
    char connect_packet[256];
    rt_size_t packet_len;
    char client_id[32];
    
    rt_kprintf("[MQTT] Connecting to broker: %s:%d\n", 
               MQTT_BROKER_HOST, MQTT_BROKER_PORT);
    
    /* 生成客户端ID */
    rt_snprintf(client_id, sizeof(client_id), 
               "iot_sensor_%08x", rt_tick_get());
    
    /* 构造连接报文 */
    packet_len = mqtt_build_connect_packet(connect_packet, client_id);
    
    /* 发送连接报文 */
    if (mqtt_send_packet(connect_packet, packet_len) != RT_EOK) {
        rt_kprintf("[MQTT] Connect failed\n");
        return -RT_ERROR;
    }
    
    mqtt_state = MQTT_STATE_CONNECTED;
    rt_kprintf("[MQTT] Connected to broker\n");
    
    return RT_EOK;
}

/* 初始化MQTT客户端 */
rt_err_t mqtt_client_init(void) {
    rt_err_t ret;
    
    /* 创建互斥锁 */
    mqtt_mutex = rt_mutex_create("mqtt_mutex", RT_IPC_FLAG_FIFO);
    if (mqtt_mutex == RT_NULL) {
        rt_kprintf("[MQTT] Create mutex failed\n");
        return -RT_ERROR;
    }
    
    /* 连接到MQTT代理 */
    ret = mqtt_connect_to_broker();
    if (ret != RT_EOK) {
        return ret;
    }
    
    return RT_EOK;
}

/* 发布数据到MQTT主题 */
rt_err_t mqtt_publish_data(const char *topic, const char *data) {
    char publish_packet[512];
    rt_size_t packet_len;
    
    if (mqtt_state != MQTT_STATE_CONNECTED) {
        rt_kprintf("[MQTT] Not connected\n");
        return -RT_ERROR;
    }
    
    rt_mutex_take(mqtt_mutex, RT_WAITING_FOREVER);
    
    /* 构造发布报文 */
    packet_len = mqtt_build_publish_packet(publish_packet, topic, data);
    
    /* 发送发布报文 */
    if (mqtt_send_packet(publish_packet, packet_len) != RT_EOK) {
        rt_mutex_release(mqtt_mutex);
        rt_kprintf("[MQTT] Publish failed\n");
        return -RT_ERROR;
    }
    
    rt_mutex_release(mqtt_mutex);
    
    return RT_EOK;
}

/* 订阅主题 */
rt_err_t mqtt_subscribe_topic(const char *topic) {
    /* TODO: 实现订阅功能 */
    return RT_EOK;
}

/* 断开MQTT连接 */
rt_err_t mqtt_disconnect(void) {
    char disconnect_packet[2] = {MQTT_MSG_DISCONNECT, 0};
    
    mqtt_send_packet(disconnect_packet, 2);
    mqtt_state = MQTT_STATE_DISCONNECTED;
    
    rt_kprintf("[MQTT] Disconnected\n");
    
    return RT_EOK;
}

/* 获取MQTT连接状态 */
mqtt_state_t mqtt_get_state(void) {
    return mqtt_state;
}