
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
#include <string.h>
#include "esp_system.h"
#include "esp_timer.h"
#include "esp_log.h"
#include "esp_console.h"
#include "argtable3/argtable3.h"
#include "esp_vfs_dev.h"
#include "esp_vfs_fat.h"
#include "nvs.h"
#include "nvs_flash.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_flash.h"
#include "esp_mac.h"
#include "esp_chip_info.h"

#include "esp_wifi.h"
#include "esp_wifi_types.h"

#include "app_wifi.h"
#include "app_nvs.h"
#include "app_spitask.h"


#ifndef CONFIG_CONSOLE_MAX_COMMAND_LINE_LENGTH
#define CONFIG_CONSOLE_MAX_COMMAND_LINE_LENGTH 80
#endif

#define PROMPT_STR "PDP2011-ESP"

static const char *TAG = "app_cons";

static uint8_t basemac[8];

static int get_info(int argc, char **argv)
{
   char *model;
   int i;
   uint32_t flash_size;

   esp_chip_info_t info;
   esp_chip_info(&info);
   esp_flash_get_size(NULL, &flash_size);
   printf("IDF Version:%s\r\n", esp_get_idf_version());
   printf("Chip info:\r\n");
   switch (info.model) {
      case CHIP_ESP32:
         model="ESP32";
         break;

      case CHIP_ESP32S2:
         model="ESP32-S2";
         break;

      case CHIP_ESP32S3:
         model="ESP32-S3";
         break;

      case CHIP_ESP32C3:
         model="ESP32-C3";
         break;

      case CHIP_ESP32C2:
         model="ESP32-C2";
         break;

      default:
         model="*unknown*";
   }
   printf("\tmodel:%s\r\n", model);
   printf("\tcores:%d\r\n", info.cores);
   printf("\tfeature:%s%s%s%s%ld%s\r\n",
      info.features & CHIP_FEATURE_WIFI_BGN ? "/802.11bgn" : "",
      info.features & CHIP_FEATURE_BLE ? "/BLE" : "",
      info.features & CHIP_FEATURE_BT ? "/BT" : "",
      info.features & CHIP_FEATURE_EMB_FLASH ? "/Embedded-Flash:" : "/External-Flash:",
      flash_size / (1024 * 1024), " MB");
   printf("\trevision number:%d\r\n", info.revision);
   esp_base_mac_addr_get(basemac);
   printf("burntin base mac address:");
   for (i=0; i<6; i++) {
      printf("%02x", basemac[i]);
      if (i<5) {
         printf(":");
      } else {
         printf("\n");
      }
   }
   printf("current wifi mac address:");
   for (i=0; i<6; i++) {
      printf("%02x", curr_wifi_mac[i]);
      if (i<5) {
         printf(":");
      } else {
         printf("\n");
      }
   }
   return 0;
}

static void register_info(void)
{
   const esp_console_cmd_t cmd = {
      .command = "info",
      .help = "get version of chip and SDK",
      .hint = NULL,
      .func = &get_info,
   };
   ESP_ERROR_CHECK( esp_console_cmd_register(&cmd) );
}


// tasks command - straight from esp-idf example

#ifdef CONFIG_FREERTOS_USE_STATS_FORMATTING_FUNCTIONS

static int tasks_info(int argc, char **argv)
{
   const size_t bytes_per_task = 40; /* see vTaskList description */
   char *task_list_buffer = malloc(uxTaskGetNumberOfTasks() * bytes_per_task);

   if (task_list_buffer == NULL) {
      ESP_LOGE(TAG, "failed to allocate buffer for vTaskList output");
      return 1;
   }
   fputs("Task Name\tStatus\tPrio\tHWM\tTask#", stdout);
#ifdef CONFIG_FREERTOS_VTASKLIST_INCLUDE_COREID
   fputs("\tAffinity", stdout);
#endif
   fputs("\n", stdout);
   vTaskList(task_list_buffer);
   fputs(task_list_buffer, stdout);
   free(task_list_buffer);

   return 0;
}


static void register_tasks(void)
{
   const esp_console_cmd_t cmd = {
      .command = "tasks",
      .help = NULL,
      .hint = NULL,
      .func = &tasks_info,
   };
   ESP_ERROR_CHECK( esp_console_cmd_register(&cmd) );
}

#endif


// restart command

static int restart(int argc, char **argv)
{
   ESP_LOGI(TAG, "restart...");
   esp_restart();
}

static void register_restart(void)
{
   const esp_console_cmd_t cmd = {
      .command = "restart",
      .help = NULL,
      .hint = NULL,
      .func = &restart,
   };
   ESP_ERROR_CHECK( esp_console_cmd_register(&cmd) );
}


// erasenvs command

static int erasenvs(int argc, char **argv)
{
   esp_err_t res;

   res = nvs_flash_init();
   if (res!=ESP_OK) {
      ESP_LOGE(TAG, "error %d from nvs_flash_init", res);
   }
   res = nvs_flash_erase();
   if (res!=ESP_OK) {
      ESP_LOGE(TAG, "error %d from nvs_flash_erase", res);
   }
   res = nvs_flash_init();
   if (res!=ESP_OK) {
      ESP_LOGE(TAG, "error %d from 2nd nvs_flash_init", res);
   }
   return 0;
}

static void register_erasenvs(void)
{
   const esp_console_cmd_t cmd = {
      .command = "erasenvs",
      .help = NULL,
      .hint = NULL,
      .func = &erasenvs,
   };
   ESP_ERROR_CHECK( esp_console_cmd_register(&cmd) );
}


// dumpnvs

static int cmd_dumpnvs(int argc, char **argv)
{
   dumpnvs();
   return 0;
}

static void register_dumpnvs(void)
{
   const esp_console_cmd_t cmd = {
      .command = "dumpnvs",
      .help = NULL,
      .hint = NULL,
      .func = &cmd_dumpnvs,
   };
   ESP_ERROR_CHECK( esp_console_cmd_register(&cmd) );
}


// stats

static int cmd_stats(int argc, char **argv)
{
   int64_t t1, td;
   int64_t secs, mins, hours, days;

   static int64_t t0 = 0;
   static uint32_t spitrx = 0;
   static uint32_t recvtrx = 0;
   static uint32_t xmittrx = 0;
   static uint32_t bothtrx = 0;
   static uint32_t nomagik = 0;
   static uint32_t recvbytes = 0;
   static uint32_t xmitbytes = 0;

   t1=esp_timer_get_time();
   secs = t1 / 1000000;
   mins = secs / 60;
   hours = mins / 60;
   days = hours / 24;
   secs = secs % 60;
   mins = mins % 60;
   hours = hours % 24;
   printf("up %lld days, %02lld:%02lld:%02lld", days, hours, mins, secs);
   td = t1 - t0;
   secs = td / 1000000;
   mins = secs / 60;
   hours = mins / 60;
   days = hours / 24;
   secs = secs % 60;
   mins = mins % 60;
   hours = hours % 24;
   printf(", delta %lld days, %02lld:%02lld:%02lld\n", days, hours, mins, secs);
   t0 = t1;

   printf("#spi trx     : %12ld", noof_spitrx);
   printf(" %12ld\n", noof_spitrx - spitrx);
   spitrx = noof_spitrx;
   printf("#spi trx fdx : %12ld", noof_bothtrx);
   printf(" %12ld\n", noof_bothtrx - bothtrx);
   bothtrx = noof_bothtrx;
   printf("#spi nomagik : %12ld", noof_nomagik);
   printf(" %12ld\n", noof_nomagik - nomagik);
   nomagik = noof_nomagik;
   printf("#xmit frames : %12ld", noof_xmittrx);
   printf(" %12ld\n", noof_xmittrx - xmittrx);
   xmittrx = noof_xmittrx;
   printf("#xmit bytes  : %12ld", noof_xmitbytes);
   printf(" %12ld\n", noof_xmitbytes - xmitbytes);
   xmitbytes = noof_xmitbytes;
   printf("#recv frames : %12ld", noof_recvtrx);
   printf(" %12ld\n", noof_recvtrx - recvtrx);
   recvtrx = noof_recvtrx;
   printf("#recv bytes  : %12ld", noof_recvbytes);
   printf(" %12ld\n", noof_recvbytes - recvbytes);
   recvbytes = noof_recvbytes;
   return 0;
}

static void register_stats(void)
{
   const esp_console_cmd_t cmd = {
      .command = "stats",
      .help = NULL,
      .hint = NULL,
      .func = &cmd_stats,
   };
   ESP_ERROR_CHECK( esp_console_cmd_register(&cmd) );
}

// xmitprint

static struct {
   struct arg_end *end;
   struct arg_int *val;
} xmitprint_args;

static int set_xmitprint(int argc, char **argv)
{
   int nerrors;

   nerrors = arg_parse(argc, argv, (void **) &xmitprint_args);
   if (nerrors != 0) {
      arg_print_errors(stderr, xmitprint_args.end, argv[0]);
      return 1;
   }
   xmitprint = xmitprint_args.val->ival[0];
   return 0;
}

static void register_xmitprint(void)
{
   const esp_console_cmd_t cmd = {
      .command = "xmitprint",
      .help = NULL,
      .hint = NULL,
      .func = &set_xmitprint,
      .argtable = &xmitprint_args
   };

   xmitprint_args.val = arg_int0(NULL, NULL, "<val>", NULL);
   xmitprint_args.end = arg_end(1);

   ESP_ERROR_CHECK( esp_console_cmd_register(&cmd) );
}

// recvprint

static struct {
   struct arg_int *val;
   struct arg_end *end;
} recvprint_args;

static int set_recvprint(int argc, char **argv)
{
   int nerrors;

   nerrors = arg_parse(argc, argv, (void **) &recvprint_args);
   if (nerrors != 0) {
      arg_print_errors(stderr, recvprint_args.end, argv[0]);
      return 1;
   }
   recvprint = recvprint_args.val->ival[0];
   return 0;
}

static void register_recvprint(void)
{
   const esp_console_cmd_t cmd = {
      .command = "recvprint",
      .help = NULL,
      .hint = NULL,
      .func = &set_recvprint,
      .argtable = &recvprint_args
   };

   recvprint_args.val = arg_int0(NULL, NULL, "<val>", NULL);
   recvprint_args.end = arg_end(1);

   ESP_ERROR_CHECK( esp_console_cmd_register(&cmd) );
}


// wifi

static struct {
   struct arg_str *ssid;
   struct arg_str *password;
   struct arg_end *end;
} wifi_args;

static int do_wifi(int argc, char **argv)
{
   int nerrors;
   nvs_handle_t nvshandle;
   wifi_mode_t mode;
   wifi_ps_type_t ps_type;
   int err;
   wifi_ap_record_t ap_info;
   int i;

   nerrors = arg_parse(argc, argv, (void **) &wifi_args);
   if (nerrors != 0) {
      arg_print_errors(stderr, wifi_args.end, argv[0]);
      return 1;
   }

   if (wifi_args.ssid->count != 0) {
      err=nvs_open("PDP2011config", NVS_READWRITE, &nvshandle);
      if (err!=ESP_OK) {
         ESP_LOGE(TAG, "couldn't open nvs, errorcode=%d", err);
         return 1;
      }
      err=nvs_set_str(nvshandle, "ssid", wifi_args.ssid->sval[0]);
      if (err!=ESP_OK) {
         ESP_LOGE(TAG, "couldn't write nvs s, errorcode=%d", err);
         return 1;
      }
      err=nvs_set_str(nvshandle, "pass", wifi_args.password->sval[0]);
      if (err!=ESP_OK) {
         ESP_LOGE(TAG, "couldn't write nvs p, errorcode=%d", err);
         return 1;
      }
      err=nvs_commit(nvshandle);
      if (err!=ESP_OK) {
         ESP_LOGE(TAG, "couldn't commit nvs, errorcode=%d", err);
         return 1;
      }
      nvs_close(nvshandle);
      printf("configuration stored in nvs, restart to activate\n");
      return 0;
   }

   err=esp_wifi_get_mode(&mode);
   printf("esp_wifi_get_mode = ");
   if (err==ESP_OK) {
      switch (mode) {
         case WIFI_MODE_NULL:
            printf("WIFI_MODE_NULL");
            break;
         case WIFI_MODE_STA:
            printf("WIFI_MODE_STA");
            break;
         case WIFI_MODE_AP:
            printf("WIFI_MODE_AP");
            break;
         case WIFI_MODE_APSTA:
            printf("WIFI_MODE_APSTA");
            break;
         case WIFI_MODE_MAX:
            printf("WIFI_MODE_MAX");
            break;
         default:
            printf("unknown %d", mode);
      }
   } else {
      printf("error 0x%04x", err);
   }
   printf("\n");

   err=esp_wifi_sta_get_ap_info(&ap_info);
   if (err!=ESP_OK) {
      ESP_LOGE(TAG, "couldn't get ap info, err=%d", err);
      return 1;
   }
   printf("ssid = '%s' ", ap_info.ssid);
   printf("bssid =");
   for (i=0; i<6; i++) printf(" %02x", ap_info.bssid[i]);
   printf("\n");

   printf("channel = %d ", ap_info.primary);
   switch (ap_info.second) {
      case WIFI_SECOND_CHAN_NONE:
//         printf("(WIFI_SECOND_CHAN_NONE) ");
         break;
      case WIFI_SECOND_CHAN_ABOVE:
         printf("(WIFI_SECOND_CHAN_ABOVE) ");
         break;
      case WIFI_SECOND_CHAN_BELOW:
         printf("(WIFI_SECOND_CHAN_BELOW) ");
         break;
      default:
         printf("(secondchannel unknown value %d) ", ap_info.second);
   }
   printf("rssi = %d\n", ap_info.rssi);

   printf("phy_11b=%s", ap_info.phy_11b?"yes":"no");
   printf(" phy_11g=%s", ap_info.phy_11g?"yes":"no");
   printf(" phy_11n=%s", ap_info.phy_11n?"yes":"no");
   printf(" phy_lr=%s", ap_info.phy_lr?"yes":"no");
   printf(" phy_lr=%s", ap_info.phy_lr?"yes":"no");
   printf(" wps=%s", ap_info.wps?"yes":"no");
   printf(" ftm_r=%s", ap_info.ftm_responder?"yes":"no");
   printf(" ftm_i=%s", ap_info.ftm_initiator?"yes":"no");
   printf("\n");

   err=esp_wifi_get_ps(&ps_type);
   printf("esp_wifi_get_ps = ");
   if (err==ESP_OK) {
      switch (ps_type) {
         case WIFI_PS_NONE:
            printf("WIFI_PS_NONE");
            break;
         case WIFI_PS_MIN_MODEM:
            printf("WIFI_PS_MIN_MODEM");
            break;
         case WIFI_PS_MAX_MODEM:
            printf("WIFI_PS_MAX_MODEM");
            break;
         default:
            printf("unknown %d", ps_type);
      }
   } else {
      printf("error 0x%04x", err);
   }
   printf("\n");

//    err=esp_wifi_get_max_tx_power(&power);
//    printf("esp_wifi_get_max_tx_power = ");
//    if (err==ESP_OK) {
//       printf("%d", power);
//    } else {
//       printf("error 0x%04x", err);
//    }
//    printf("\n");

   return 0;
}

static void register_wifi(void)
{
   const esp_console_cmd_t cmd = {
      .command = "wifi",
      .help = "get and set esp32 wifi settings",
      .hint = NULL,
      .func = &do_wifi,
      .argtable = &wifi_args
   };

   wifi_args.ssid = arg_str0(NULL, NULL, "<ssid>", "SSID of AP");
   wifi_args.password = arg_str0(NULL, NULL, "<pass>", "PSK of AP");
   wifi_args.end = arg_end(2);

   ESP_ERROR_CHECK( esp_console_cmd_register(&cmd) );
}


// wifiopt

static struct {
   struct arg_str *opt;
   struct arg_end *end;
} wifi_opt;


static int do_wifiopt(int argc, char **argv)
{
   int nerrors;
   nvs_handle_t nvshandle;
   int err;

   nerrors = arg_parse(argc, argv, (void **) &wifi_opt);
   if (nerrors != 0) {
      arg_print_errors(stderr, wifi_opt.end, argv[0]);
      return 1;
   }

   if (wifi_opt.opt->count != 0) {
      if (!strcasecmp("wifi_ps_none", wifi_opt.opt->sval[0])) {
         err=nvs_open("PDP2011config", NVS_READWRITE, &nvshandle);
         if (err!=ESP_OK) {
            ESP_LOGE(TAG, "couldn't open nvs, errorcode=%d", err);
            return 1;
         }
         err=nvs_set_str(nvshandle, "powersave", wifi_opt.opt->sval[0]);
         if (err!=ESP_OK) {
            ESP_LOGE(TAG, "couldn't write nvs p, errorcode=%d", err);
            return 1;
         }
         esp_wifi_set_ps(WIFI_PS_NONE);
         nvs_close(nvshandle);
         printf("wifi_ps_none set\n");
         return 0;
      }
      if (!strcasecmp("wifi_ps_min_modem", wifi_opt.opt->sval[0])) {
         err=nvs_open("PDP2011config", NVS_READWRITE, &nvshandle);
         if (err!=ESP_OK) {
            ESP_LOGE(TAG, "couldn't open nvs, errorcode=%d", err);
            return 1;
         }
         err=nvs_set_str(nvshandle, "powersave", wifi_opt.opt->sval[0]);
         if (err!=ESP_OK) {
            ESP_LOGE(TAG, "couldn't write nvs p, errorcode=%d", err);
            return 1;
         }
         esp_wifi_set_ps(WIFI_PS_MIN_MODEM);
         nvs_close(nvshandle);
         printf("wifi_ps_min_modem set\n");
         return 0;
      }
      if (!strcasecmp("wifi_ps_max_modem", wifi_opt.opt->sval[0])) {
         err=nvs_open("PDP2011config", NVS_READWRITE, &nvshandle);
         if (err!=ESP_OK) {
            ESP_LOGE(TAG, "couldn't open nvs, errorcode=%d", err);
            return 1;
         }
         err=nvs_set_str(nvshandle, "powersave", wifi_opt.opt->sval[0]);
         if (err!=ESP_OK) {
            ESP_LOGE(TAG, "couldn't write nvs p, errorcode=%d", err);
            return 1;
         }
         esp_wifi_set_ps(WIFI_PS_MAX_MODEM);
         nvs_close(nvshandle);
         printf("wifi_ps_max_modem set\n");
         return 0;
      }
      printf("unknown option\n");
      return 1;
   }
   printf("no option found\n");
   return 1;
}


static void register_wifiopt(void)
{
   const esp_console_cmd_t cmd = {
      .command = "wifiopt",
      .help = NULL,
      .hint = NULL,
      .func = &do_wifiopt,
      .argtable = &wifi_opt
   };

   wifi_opt.opt = arg_str0(NULL, NULL, "<option>", NULL);
   wifi_opt.end = arg_end(1);

   ESP_ERROR_CHECK( esp_console_cmd_register(&cmd) );
}


// console setup

void app_cons(void)
{
   esp_console_repl_t *repl = NULL;
   esp_console_repl_config_t repl_config = ESP_CONSOLE_REPL_CONFIG_DEFAULT();
   repl_config.prompt = PROMPT_STR ">";
   repl_config.max_cmdline_length = CONFIG_CONSOLE_MAX_COMMAND_LINE_LENGTH;


   /* Register commands */
   esp_console_register_help_command();
   register_restart();
   register_erasenvs();
   register_info();
#ifdef CONFIG_FREERTOS_USE_STATS_FORMATTING_FUNCTIONS
   register_tasks();
#endif
   register_dumpnvs();
   register_stats();
   register_recvprint();
   register_xmitprint();
   register_wifi();
   register_wifiopt();

#if defined(CONFIG_ESP_CONSOLE_UART_DEFAULT) || defined(CONFIG_ESP_CONSOLE_UART_CUSTOM)
   esp_console_dev_uart_config_t hw_config = ESP_CONSOLE_DEV_UART_CONFIG_DEFAULT();
   ESP_ERROR_CHECK(esp_console_new_repl_uart(&hw_config, &repl_config, &repl));

#elif defined(CONFIG_ESP_CONSOLE_USB_CDC)
   esp_console_dev_usb_cdc_config_t hw_config = ESP_CONSOLE_DEV_CDC_CONFIG_DEFAULT();
   ESP_ERROR_CHECK(esp_console_new_repl_usb_cdc(&hw_config, &repl_config, &repl));

#elif defined(CONFIG_ESP_CONSOLE_USB_SERIAL_JTAG)
   esp_console_dev_usb_serial_jtag_config_t hw_config = ESP_CONSOLE_DEV_USB_SERIAL_JTAG_CONFIG_DEFAULT();
   ESP_ERROR_CHECK(esp_console_new_repl_usb_serial_jtag(&hw_config, &repl_config, &repl));

#else
#error Unsupported console type
#endif

   ESP_ERROR_CHECK(esp_console_start_repl(repl));
}

