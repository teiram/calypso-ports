
#ifndef INCL_APP_WIFI_H
#define INCL_APP_WIFI_H

typedef struct {
   uint8_t *buf;
   int buflen;
   void *buf_handle;
   void (*free_buf_handle)(void *buf_handle);
} recv_queue_t;

extern QueueHandle_t recv_queue;

extern uint8_t curr_wifi_mac[6];
extern int recvprint;
extern int xmitprint;


void wifi_init_sta(void);

#endif

