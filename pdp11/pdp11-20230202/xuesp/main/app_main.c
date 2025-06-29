
//
// Copyright (c) 2008-2023 Sytse van Slooten
//
// Permission is hereby granted to any person obtaining a copy of these VHDL source files and
// other language source files and associated documentation files ("the materials") to use
// these materials solely for personal, non-commercial purposes.
// You are also granted permission to make changes to the materials, on the condition that this
// copyright notice is retained unchanged.
//
// The materials are distributed in the hope that they will be useful, but WITHOUT ANY WARRANTY;
// without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
//


#include <stdio.h>
#include <stdint.h>
#include <stddef.h>
#include <string.h>

#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/semphr.h"
#include "freertos/queue.h"
#include "freertos/event_groups.h"

#include "lwip/sockets.h"
#include "lwip/dns.h"
#include "lwip/netdb.h"
#include "lwip/igmp.h"

#include "esp_wifi.h"
#include "esp_wifi_types.h"
#include "esp_system.h"
#include "esp_event.h"
#include "nvs_flash.h"
#include "soc/rtc_periph.h"
#include "driver/spi_slave.h"
#include "esp_log.h"
#include "driver/gpio.h"

#include "esp_event.h"
#include "esp_private/wifi.h"
#include "esp_wpa.h"

#include "app_nvs.h"
#include "app_spitask.h"
#include "app_wifi.h"
#include "app_cons.h"

static const char *TAG = "PDP2011 ESP32";

// application mainline

void app_main(void)
{
   ESP_LOGI(TAG, "start up");

   initnvs();
   wifi_init_sta();

   ESP_LOGI(TAG, "init done");

   xTaskCreate(spislave_handler_task, "spislave_handler_task", 4096, NULL, 22, NULL);

   app_cons();
}

