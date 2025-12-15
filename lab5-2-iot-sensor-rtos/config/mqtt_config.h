/**
 * mqtt_config.h - MQTT客户端配置
 */

#ifndef MQTT_CONFIG_H
#define MQTT_CONFIG_H

/* MQTT代理服务器配置 */
#define MQTT_BROKER_HOST        "test.mosquitto.org"  /* 公共MQTT代理 */
#define MQTT_BROKER_PORT        1883                  /* MQTT默认端口 */

/* MQTT连接参数 */
#define MQTT_CLIENT_ID_PREFIX   "iot_sensor_"
#define MQTT_KEEPALIVE          60                    /* 保活时间(秒) */
#define MQTT_CLEAN_SESSION      1                     /* 清理会话 */

/* 主题配置 */
#define MQTT_TOPIC_PREFIX       "lab/iot/sensor/"
#define MQTT_TOPIC_TEMPERATURE  MQTT_TOPIC_PREFIX "temperature"
#define MQTT_TOPIC_HUMIDITY     MQTT_TOPIC_PREFIX "humidity"
#define MQTT_TOPIC_STATUS       MQTT_TOPIC_PREFIX "status"
#define MQTT_TOPIC_COMMAND      MQTT_TOPIC_PREFIX "command"

/* QoS等级 */
#define MQTT_QOS_LEVEL          0                     /* 最多一次 */

/* 调试输出 */
#define MQTT_DEBUG              1

/* 安全配置（如果使用TLS） */
// #define MQTT_USE_TLS
// #define MQTT_TLS_PORT          8883

#endif /* MQTT_CONFIG_H */