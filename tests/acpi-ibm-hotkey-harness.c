/* Exercise the actual acpi_ibm_notify function with synthetic firmware events. */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define EVDEV_SUPPORT 1
#define IBM_NAME_EVENTS_GET "MHKP"
#define IBM_EVENT_FAVORITES 0x311
#define IBM_EVENT_BRIGHTNESS_UP 0x10
#define IBM_EVENT_BRIGHTNESS_DOWN 0x11
#define IBM_EVENT_MICMUTE 0x1b
#define KEY_BOOKMARKS 156
#define KEY_BRIGHTNESSDOWN 224
#define KEY_BRIGHTNESSUP 225
#define KEY_MICMUTE 248
#define ACPI_FUNCTION_TRACE_U32(...) ((void)0)
typedef void *ACPI_HANDLE;
typedef void *device_t;
typedef unsigned int UINT32;
struct acpi_ibm_softc { unsigned int events_availmask, handler_events; void *evdev; };
static int input_event, pending, key_count, keys[4], values[4], notifications, notified, handled;
static void *device_get_softc(device_t d) { return d; }
static void *acpi_get_handle(device_t d) { return d; }
static void acpi_GetInteger(void *h, const char *name, int *v)
{ (void)h; (void)name; *v = pending ? input_event : 0; pending = 0; }
static void device_printf(device_t d, const char *fmt, ...) { (void)d; (void)fmt; }
static void acpi_ibm_eventhandler(struct acpi_ibm_softc *s, int v)
{ (void)s; handled = v; }
static void evdev_push_key(void *d, int key, int value)
{ (void)d; if (key_count >= 4) abort(); keys[key_count] = key; values[key_count++] = value; }
static void evdev_sync(void *d) { (void)d; }
static void acpi_UserNotify(const char *name, void *h, int arg)
{ (void)name; (void)h; notifications++; notified = arg; }

/* The test script inserts acpi_ibm_notify from the patched FreeBSD source here. */
