/**
 * sensor_config.h - 传感器配置
 */

#ifndef SENSOR_CONFIG_H
#define SENSOR_CONFIG_H

/* 传感器类型选择 */
#define SENSOR_TYPE_DHT11       1
#define SENSOR_TYPE_DHT22       2
#define SENSOR_TYPE            SENSOR_TYPE_DHT11

/* 传感器引脚配置 */
#define DHT11_DATA_PIN          1      /* PA1 */
#define DHT_PULL_UP_ENABLE      1      /* 启用上拉电阻 */

/* 采样间隔配置 */
#define SENSOR_SAMPLE_INTERVAL  5000   /* 采样间隔(ms) */
#define SENSOR_READ_TIMEOUT     100    /* 读取超时(ms) */

/* 数据过滤配置 */
#define ENABLE_DATA_FILTER      1      /* 启用数据过滤 */
#define FILTER_WINDOW_SIZE      5      /* 滤波窗口大小 */

/* 校准偏移 */
#define TEMP_OFFSET             0.0    /* 温度偏移 */
#define HUMI_OFFSET             0.0    /* 湿度偏移 */

/* 报警阈值 */
#define TEMP_ALARM_HIGH         40.0   /* 高温报警 */
#define TEMP_ALARM_LOW          0.0    /* 低温报警 */
#define HUMI_ALARM_HIGH         80.0   /* 高湿报警 */
#define HUMI_ALARM_LOW          20.0   /* 低湿报警 */

/* 调试输出 */
#define SENSOR_DEBUG            1

#endif /* SENSOR_CONFIG_H */