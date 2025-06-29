
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
#include "soc/gpio_reg.h"
#include "driver/spi_slave.h"
#include "esp_log.h"
#include "spi_flash_mmap.h"
#include "driver/gpio.h"

#include "esp_event.h"
#include "esp_private/wifi.h"
#include "esp_wpa.h"

#include "app_nvs.h"
#include "app_printframe.h"
#include "app_spitask.h"
#include "app_wifi.h"

#define MAXPAY 1518
#define HDRLEN 12
#define BUFEXT 32
#define MINRECVFRAME 128
#define MINXMITFRAME 128


#if CONFIG_IDF_TARGET_ESP32 || CONFIG_IDF_TARGET_ESP32S2
#define GPIO_HANDSHAKE 21
#define GPIO_MOSI 23
#define GPIO_MISO 19
#define GPIO_SCLK 18
#define GPIO_CS 5

#elif CONFIG_IDF_TARGET_ESP32C3
#define GPIO_HANDSHAKE 3
#define GPIO_MOSI 7
#define GPIO_MISO 2
#define GPIO_SCLK 6
#define GPIO_CS 10

#elif CONFIG_IDF_TARGET_ESP32S3
#define GPIO_HANDSHAKE 2
#define GPIO_MOSI 11
#define GPIO_MISO 13
#define GPIO_SCLK 12
#define GPIO_CS 10

#endif //CONFIG_IDF_TARGET_ESP32 || CONFIG_IDF_TARGET_ESP32S2


#ifdef CONFIG_IDF_TARGET_ESP32
#define RCV_HOST    SPI3_HOST

#else
#define RCV_HOST    SPI2_HOST

#endif

static const char *TAG = "app_spitask";

int recvprint = 0;
int xmitprint = 0;

uint32_t crc32(const uint8_t *s,size_t n) {
   uint32_t crc=0xFFFFFFFF;

   for(size_t i=0;i<n;i++) {
      char ch=s[i];
      for(size_t j=0;j<8;j++) {
         uint32_t b=(ch^crc)&1;
         crc>>=1;
         if(b) crc=crc^0xEDB88320;
         ch>>=1;
      }
   }

   return ~crc;
}

uint32_t noof_spitrx = 0;
uint32_t noof_recvtrx = 0;
uint32_t noof_xmittrx = 0;
uint32_t noof_bothtrx = 0;
uint32_t noof_nomagik = 0;

uint32_t noof_recvbytes = 0;
uint32_t noof_xmitbytes = 0;


static uint8_t sendbuf[HDRLEN+MAXPAY+BUFEXT];              // FIXME these should be aligned on a 32bit boundary really
static uint8_t recvbuf[HDRLEN+MAXPAY+BUFEXT];
static uint8_t recvcnt=0;


// called after a transaction is queued and ready - set srdy
void my_spi_post_setup_cb(spi_slave_transaction_t *trans) {
   WRITE_PERI_REG(GPIO_OUT_W1TC_REG, (1<<GPIO_HANDSHAKE));
}

// called after transaction - clear srdy
void my_spi_post_trans_cb(spi_slave_transaction_t *trans) {
   WRITE_PERI_REG(GPIO_OUT_W1TS_REG, (1<<GPIO_HANDSHAKE));
}

void spislave_handler_task(void* pvParameters)
{
   esp_err_t res;
   spi_slave_transaction_t spi_transaction;
   int recvqueuedframes;

   // configuration of the SPI bus
   spi_bus_config_t buscfg={
      .mosi_io_num=GPIO_MOSI,
      .miso_io_num=GPIO_MISO,
      .sclk_io_num=GPIO_SCLK,
      .quadwp_io_num = -1,
      .quadhd_io_num = -1,
   };

   // configuration of the SPI slave interface
   spi_slave_interface_config_t slvcfg={
      .mode=0,
      .spics_io_num=GPIO_CS,
      .queue_size=3,
      .flags=0,
      .post_setup_cb=my_spi_post_setup_cb,
      .post_trans_cb=my_spi_post_trans_cb
   };

   // configuration of the handshake line
   gpio_config_t io_conf={
      .intr_type=GPIO_INTR_DISABLE,
      .mode=GPIO_MODE_OUTPUT,
      .pin_bit_mask=(1<<GPIO_HANDSHAKE)
   };

   // configure handshake line as output
   gpio_config(&io_conf);

   // enable pull-ups on SPI lines so we don't detect rogue pulses when no master is connected.
   gpio_set_pull_mode(GPIO_MOSI, GPIO_PULLUP_ONLY);
   gpio_set_pull_mode(GPIO_SCLK, GPIO_PULLUP_ONLY);
   gpio_set_pull_mode(GPIO_CS, GPIO_PULLUP_ONLY);

   // initialize SPI slave interface
   res=spi_slave_initialize(RCV_HOST, &buscfg, &slvcfg, SPI_DMA_CH_AUTO);
   assert(res == ESP_OK);

   // main loop
   while (1) {
      int recvframelength;
      int sendframelength;
      uint32_t crc;

      spi_transaction.length=sizeof(recvbuf)*8;
      memset(sendbuf, 0, sizeof(recvbuf));
      recvbuf[0]=0xaa;
      recvbuf[1]=0x55;
      recvbuf[2]=recvcnt++;
      recvqueuedframes = uxQueueMessagesWaiting(recv_queue);
      if (recvqueuedframes > 255) {
         recvbuf[3]=255;
      } else {
         recvbuf[3]=(uint8_t) recvqueuedframes;
      }
      recvbuf[4]=0;
      recvbuf[5]=0;
      recvbuf[6]=curr_wifi_mac[0];
      recvbuf[7]=curr_wifi_mac[1];
      recvbuf[8]=curr_wifi_mac[2];
      recvbuf[9]=curr_wifi_mac[3];
      recvbuf[10]=curr_wifi_mac[4];
      recvbuf[11]=curr_wifi_mac[5];
      recvframelength=0;
      if (recvqueuedframes > 0) {
         recv_queue_t q = { 0 } ;
         if (xQueueReceive(recv_queue, &q, portMAX_DELAY)) {
            if (q.buflen <= sizeof(recvbuf)-HDRLEN-BUFEXT) {
               memcpy(recvbuf+HDRLEN, q.buf, q.buflen);
               recvframelength=q.buflen;
               if (recvframelength < MINRECVFRAME) recvframelength=MINRECVFRAME;
               recvframelength+=4;                         // the length should include the crc field
               recvbuf[4]=(recvframelength >> 8) & 0xff;
               recvbuf[5]=recvframelength & 0xff;
               noof_recvbytes+=q.buflen;
               noof_recvtrx++;
            } else {
               ESP_LOGE(TAG, "oversized receive frame, length=%d", q.buflen);
               memset(recvbuf+HDRLEN, 0, sizeof(recvbuf)-HDRLEN);
            }
            q.free_buf_handle(q.buf_handle);
         } else {
            memset(recvbuf+HDRLEN, 0, sizeof(recvbuf)-HDRLEN);
         }
      } else {
         memset(recvbuf+HDRLEN, 0, sizeof(recvbuf)-HDRLEN);
      }

      if (recvframelength > 0 && recvprint) printframe(recvbuf, recvframelength, "rc  ");

      spi_transaction.tx_buffer=&recvbuf;
      spi_transaction.rx_buffer=&sendbuf;
      sendbuf[4]=0;
      sendbuf[5]=0;
      res = spi_slave_transmit(RCV_HOST, &spi_transaction, portMAX_DELAY);
      if (res != ESP_OK) {
         ESP_LOGE(TAG, "spi_slave_transmit error %d", res);
         continue;
      }
      noof_spitrx++;

      if (sendbuf[0]!=0xa0 || sendbuf[1]!=0xa0) {
         noof_nomagik++;
//         ESP_LOGE(TAG, "no magik in send buffer %02x %02x", sendbuf[0], sendbuf[1]);
         continue;
      }

      sendframelength =(sendbuf[4] << 8) + sendbuf[5];
      if (sendframelength > MAXPAY) {
         ESP_LOGE(TAG, "overlength frame length=%d", sendframelength);
         continue;
      }

      if (sendframelength > 0 && xmitprint) printframe(sendbuf, sendframelength, "  xm");

      if (sendframelength > 0) {
         noof_xmittrx++;
         noof_xmitbytes+=sendframelength;
         if (recvframelength != 0) noof_bothtrx++;
         if (sendframelength < MINXMITFRAME) sendframelength = MINXMITFRAME;
         crc = crc32(sendbuf+HDRLEN, sendframelength);
         sendbuf[sendframelength+HDRLEN] = crc & 0xff;
         sendbuf[sendframelength+HDRLEN+1] = (crc >> 8) & 0xff;
         sendbuf[sendframelength+HDRLEN+2] = (crc >> 16) & 0xff;
         sendbuf[sendframelength+HDRLEN+3] = (crc >> 24) & 0xff;
         res = esp_wifi_internal_tx(WIFI_IF_STA, sendbuf+HDRLEN, sendframelength+4);
         if (res != ESP_OK) {
            ESP_LOGE(TAG, "failed esp_wifi_internal_tx (0x%02x)", res);
         }
      }
      usleep(2000);
   }
}


