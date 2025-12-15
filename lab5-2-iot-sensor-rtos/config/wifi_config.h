/**
 * wifi_config.h - WiFi连接配置
 */

#ifndef WIFI_CONFIG_H
#define WIFI_CONFIG_H

/* WiFi网络配置 */
#define WIFI_SSID               "Your_WiFi_SSID"
#define WIFI_PASSWORD           "Your_WiFi_Password"

/* WiFi连接参数 */
#define WIFI_CONNECT_TIMEOUT    10000  /* 连接超时时间(ms) */
#define WIFI_RETRY_COUNT        3      /* 重试次数 */

/* ESP8266模块配置 */
#define ESP8266_BAUDRATE        115200 /* 波特率 */
#define ESP8266_UART            "uart2" /* 串口设备名 */

/* AT指令超时时间 */
#define AT_CMD_TIMEOUT_SHORT    3000   /* 短命令超时(ms) */
#define AT_CMD_TIMEOUT_LONG     10000  /* 长命令超时(ms) */

/* 调试输出 */
#define WIFI_DEBUG              1

/* WiFi事件定义 */
typedef enum {
    WIFI_EVENT_CONNECTED = 0,
    WIFI_EVENT_DISCONNECTED,
    WIFI_EVENT_GOT_IP,
    WIFI_EVENT_CONNECT_FAILED
} wifi_event_t;

#endif /* WIFI_CONFIG_H */