
#ifndef INCL_APP_SPITASK_H
#define INCL_APP_SPITASK_H

void spislave_handler_task(void* pvParameters);

extern uint32_t noof_spitrx;
extern uint32_t noof_recvtrx;
extern uint32_t noof_xmittrx;
extern uint32_t noof_bothtrx;
extern uint32_t noof_nomagik;

extern uint32_t noof_recvbytes;
extern uint32_t noof_xmitbytes;

#endif

