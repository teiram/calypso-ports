
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


#include "app_printframe.h"
#include "app_wifi.h"

// static const char *TAG = "app_printframe";

void printframe(uint8_t *p, int len, char *title)
{
   int framelength;
   int i;
   int notme;

   if (len <= 0) return;
   if (p == NULL) return;
   if (title == NULL) return;

   framelength= (*(p+4)<<8) + *(p+5);
   printf("%s[%04d] ", title, framelength);

   notme=0;
   for (i=12; i<18; i++) {
      if (*(p+i)!=curr_wifi_mac[i-12]) notme++;
   }
   if (notme) {
      for (i=12; i<18; i++) {
         printf("%02x", *(p+i));
      }
   } else {
      printf("    *me*    ");
   }

   printf("<");

   notme=0;
   for (i=18; i<24; i++) {
      if (*(p+i)!=curr_wifi_mac[i-18]) notme++;
   }
   if (notme) {
      for (i=18; i<24; i++) {
         printf("%02x", *(p+i));
      }
   } else {
      printf("    *me*    ");
   }

   if (*(p+24)==0x08 && *(p+25)==0x00) {
      printf(" | ip | ");
   } else if (*(p+24)==0x08 && *(p+25)==0x06) {
      printf(" |arp | ");
   } else {
      printf(" |%02x%02x| ", *(p+24), *(p+25));
   }
   printf("\n");
}
