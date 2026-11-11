#ifndef P130_RTC_H
#define P130_RTC_H
#include <stdint.h>

/* ATM-host-only, read-only DS12887 service. */
void p130_rtc_probe(void);
void p130_rtc_read_current(void);
extern volatile uint8_t p130_rtc_available;
extern volatile uint8_t p130_rtc_backend;
extern volatile char p130_rtc_hour[2];
extern volatile char p130_rtc_minute[2];
extern volatile char p130_rtc_second[2];
#endif
