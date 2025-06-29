
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

#include "esp_system.h"
#include "nvs_flash.h"
#include "esp_log.h"

#include "app_nvs.h"

// static const char *TAG = "app_nvs";

void initnvs(void)
{
   esp_err_t res;

   res = nvs_flash_init();

   if (res == ESP_ERR_NVS_NO_FREE_PAGES || res == ESP_ERR_NVS_NEW_VERSION_FOUND) {
      ESP_ERROR_CHECK(nvs_flash_erase());
      res = nvs_flash_init();
   }
   ESP_ERROR_CHECK(res);

//   dumpnvs();
}

void dumpnvs(void)
{
   nvs_iterator_t it;
   esp_err_t res;

   res=nvs_entry_find("nvs", NULL, NVS_TYPE_ANY, &it);
   if (res == ESP_ERR_NVS_NOT_FOUND) {
      printf("nvs is empty\n");
      return;
   }
   if (res != ESP_OK) {
      printf("error from nvs_entry_find - recommend erase nvs\n");
      return;
   }
   while (it != NULL) {
      nvs_entry_info_t info;
      nvs_entry_info(it, &info);
      nvs_entry_next(&it);
      printf("ns '%-16s', key '%-16s', type %02x, value=", info.namespace_name, info.key, info.type);
      switch (info.type) {
         case NVS_TYPE_U8:
            {
               uint8_t v;
               nvs_handle_t h;

               nvs_open(info.namespace_name, NVS_READONLY, &h);
               nvs_get_u8(h, info.key, &v);
               nvs_close(h);
               printf("0x%02x (%u)", v & 0xff, v);
            }
            break;

         case NVS_TYPE_I8:
            {
               int8_t v;
               nvs_handle_t h;

               nvs_open(info.namespace_name, NVS_READONLY, &h);
               nvs_get_i8(h, info.key, &v);
               nvs_close(h);
               printf("0x%02x (%d)", v & 0xff, v);
            }
            break;

         case NVS_TYPE_U16:
            {
               uint16_t v;
               nvs_handle_t h;

               nvs_open(info.namespace_name, NVS_READONLY, &h);
               nvs_get_u16(h, info.key, &v);
               nvs_close(h);
               printf("0x%04x (%u)", v & 0xffff, v);
            }
            break;

         case NVS_TYPE_I16:
            {
               int16_t v;
               nvs_handle_t h;

               nvs_open(info.namespace_name, NVS_READONLY, &h);
               nvs_get_i16(h, info.key, &v);
               nvs_close(h);
               printf("0x%04x (%d)", v & 0xffff, v);
            }
            break;

         case NVS_TYPE_U32:
            {
               uint32_t v;
               nvs_handle_t h;

               nvs_open(info.namespace_name, NVS_READONLY, &h);
               nvs_get_u32(h, info.key, &v);
               nvs_close(h);
               printf("0x%08lx (%lu)", v, v);
            }
            break;

         case NVS_TYPE_I32:
            {
               int32_t v;
               nvs_handle_t h;

               nvs_open(info.namespace_name, NVS_READONLY, &h);
               nvs_get_i32(h, info.key, &v);
               nvs_close(h);
               printf("0x%08lx (%lu)", v, v);
            }
            break;

         case NVS_TYPE_U64:
            {
               uint64_t v;
               nvs_handle_t h;

               nvs_open(info.namespace_name, NVS_READONLY, &h);
               nvs_get_u64(h, info.key, &v);
               nvs_close(h);
               printf("0x%016llx (%llu)", v, v);
            }
            break;

         case NVS_TYPE_I64:
            {
               int64_t v;
               nvs_handle_t h;

               nvs_open(info.namespace_name, NVS_READONLY, &h);
               nvs_get_i64(h, info.key, &v);
               nvs_close(h);
               printf("0x%016llx (%llu)", v, v);
            }
            break;

         case NVS_TYPE_STR:
            {
               size_t length;
               char str[32];
               nvs_handle_t h;
               int i;

               length = sizeof(str);
               nvs_open(info.namespace_name, NVS_READONLY, &h);
               nvs_get_str(h, info.key, str, &length);
               nvs_close(h);
               if (length > sizeof(str)) length = sizeof(str);
               printf("'");
               for (i = 0; i < length; i++) {
                  printf("%c", str[i]);
               }
               if (length == sizeof(str)) printf("...");
               printf("'");
            }
            break;

         case NVS_TYPE_BLOB:
            {
               size_t length;
               uint8_t blob[32];
               nvs_handle_t h;
               int i;

               length = sizeof(blob);
               nvs_open(info.namespace_name, NVS_READONLY, &h);
               nvs_get_blob(h, info.key, &blob, &length);
               nvs_close(h);
               if (length > sizeof(blob)) length = sizeof(blob);
               for (i = 0; i < length; i++) {
                  printf("%02x ", blob[i]);
               }
            }

         default:
            break;
      }
      printf("\n");
   }
}
