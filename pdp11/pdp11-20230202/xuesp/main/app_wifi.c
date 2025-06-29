
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
#include "app_printframe.h"
#include "app_spitask.h"
#include "app_wifi.h"


uint8_t curr_wifi_mac[6];

QueueHandle_t recv_queue = {NULL};

static EventGroupHandle_t s_wifi_event_group;

#ifndef EXAMPLE_ESP_WIFI_SSID
#define EXAMPLE_ESP_WIFI_SSID "defaultssid"
#endif

#ifndef EXAMPLE_ESP_WIFI_PASS
#define EXAMPLE_ESP_WIFI_PASS "defaultpass"
#endif

#define EXAMPLE_ESP_MAXIMUM_RETRY 10

#define WIFI_CONNECTED_BIT BIT0
#define WIFI_FAIL_BIT      BIT1

static const char *TAG = "app_wifi";

static int s_retry_num = 0;

static void event_handler(void* arg, esp_event_base_t event_base, int32_t event_id, void* event_data)
{
   if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_START) {
      esp_wifi_connect();
   } else if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_DISCONNECTED) {
      if (s_retry_num < EXAMPLE_ESP_MAXIMUM_RETRY) {
         esp_wifi_connect();
         s_retry_num++;
         ESP_LOGI(TAG, "retry to connect to the AP");
      } else {
         xEventGroupSetBits(s_wifi_event_group, WIFI_FAIL_BIT);
      }
      ESP_LOGI(TAG,"connect to the AP fail");
   } else if (event_base == IP_EVENT && event_id == IP_EVENT_STA_GOT_IP) {
      ip_event_got_ip_t* event = (ip_event_got_ip_t*) event_data;
      ESP_LOGI(TAG, "got ip:" IPSTR, IP2STR(&event->ip_info.ip));
      s_retry_num = 0;
      xEventGroupSetBits(s_wifi_event_group, WIFI_CONNECTED_BIT);
   }
}

esp_err_t wlan_sta_rx_callback(void *buffer, uint16_t len, void *eb)
{
   esp_err_t ret = ESP_OK;
   recv_queue_t rq = {0};

   uint8_t b12, b13;
   int want;

   rq.buflen = len;
   rq.buf = buffer;
   rq.buf_handle = eb;
   rq.free_buf_handle = esp_wifi_internal_free_rx_buffer;

   b12=*((uint8_t *) buffer + 12);
   b13=*((uint8_t *) buffer + 13);

   want = 0;
   if (b12==0x08 && b13==0x06) {
      want = 1;
   }
   if (b12==0x08 && b13==0x00) {
      want = 1;
   }


   if (want) {
//      printf("want, b12=%02x, b13=%02x\n", b12, b13);
      ret = xQueueSend(recv_queue, &rq, portMAX_DELAY);
      if (ret != pdTRUE) {
         ESP_LOGE(TAG, "error adding buffer to recv queue\n");
         esp_wifi_internal_free_rx_buffer(eb);
         return ESP_OK;
      }
      return ESP_OK;
   } else {
      esp_wifi_internal_free_rx_buffer(eb);
      return ESP_OK;
   }
}


void wifi_init_sta(void)
{
   s_wifi_event_group = xEventGroupCreate();
   nvs_handle_t nvshandle;
   size_t ssidlen, passlen;
   char powersave[32];
   size_t powersavelen;
   int err;

   ESP_ERROR_CHECK(esp_netif_init());

   ESP_ERROR_CHECK(esp_event_loop_create_default());
   esp_netif_create_default_wifi_sta();

   wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
   ESP_ERROR_CHECK(esp_wifi_init(&cfg));

   ESP_ERROR_CHECK(esp_wifi_set_storage(WIFI_STORAGE_RAM) );

   ESP_ERROR_CHECK(esp_wifi_get_mac(WIFI_IF_STA, curr_wifi_mac));

   esp_event_handler_instance_t instance_any_id;
   esp_event_handler_instance_t instance_got_ip;
   ESP_ERROR_CHECK(esp_event_handler_instance_register(WIFI_EVENT, ESP_EVENT_ANY_ID, &event_handler, NULL, &instance_any_id));
   ESP_ERROR_CHECK(esp_event_handler_instance_register(IP_EVENT, IP_EVENT_STA_GOT_IP, &event_handler, NULL, &instance_got_ip));

   wifi_config_t wifi_config = {
      .sta = {
         .ssid = EXAMPLE_ESP_WIFI_SSID,
         .password = EXAMPLE_ESP_WIFI_PASS,
         .threshold.authmode = WIFI_AUTH_WPA2_PSK,
         .pmf_cfg = {
            .capable = true,
            .required = false
         },
      },
   };
   memset(powersave, 0, sizeof(powersave));
   err=nvs_open("PDP2011config", NVS_READONLY, &nvshandle);
   if (err==ESP_OK) {
      ssidlen=sizeof(wifi_config.sta.ssid);
      nvs_get_str(nvshandle, "ssid", (char *) &wifi_config.sta.ssid[0], &ssidlen);
      passlen=sizeof(wifi_config.sta.password);
      nvs_get_str(nvshandle, "pass", (char *) &wifi_config.sta.password[0], &passlen);
      powersavelen=sizeof(powersave);
      nvs_get_str(nvshandle, "powersave", (char *) &powersave, &powersavelen);
      nvs_close(nvshandle);
   }
   ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));
   ESP_ERROR_CHECK(esp_wifi_set_config(WIFI_IF_STA, &wifi_config));
   ESP_ERROR_CHECK(esp_wifi_start());

   if (!strcasecmp("wifi_ps_none", powersave) || strlen(powersave) < 2) {
      ESP_ERROR_CHECK(esp_wifi_set_ps(WIFI_PS_NONE));
   }
   if (!strcasecmp("wifi_ps_min_modem", powersave)) {
      ESP_ERROR_CHECK(esp_wifi_set_ps(WIFI_PS_MIN_MODEM));
   }
   if (!strcasecmp("wifi_ps_max_modem", powersave)) {
      ESP_ERROR_CHECK(esp_wifi_set_ps(WIFI_PS_MAX_MODEM));
   }
   recv_queue=xQueueCreate(20, sizeof(recv_queue_t));

   ESP_LOGI(TAG, "wifi setup finished");

   EventBits_t bits = xEventGroupWaitBits(s_wifi_event_group, WIFI_CONNECTED_BIT | WIFI_FAIL_BIT, pdFALSE, pdFALSE, portMAX_DELAY);

   if (bits & WIFI_CONNECTED_BIT) {
      ESP_LOGI(TAG, "sta connected to ap");
      esp_wifi_internal_reg_rxcb(ESP_IF_WIFI_STA, (wifi_rxcb_t) wlan_sta_rx_callback);
      ESP_LOGI(TAG, "sta callback registered");
   } else if (bits & WIFI_FAIL_BIT) {
      ESP_LOGI(TAG, "sta failed to connect to ap");
   } else {
      ESP_LOGE(TAG, "UNEXPECTED EVENT");
   }
}


