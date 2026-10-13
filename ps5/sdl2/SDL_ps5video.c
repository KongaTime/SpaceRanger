/*
 * SpaceRanger for the PlayStation 5 - SDL2's video driver for the console.
 *
 * Ported to SDL2 from PS5_Dusklight's SDL3 driver (griches). The console has
 * one output and no windows: SDL gets one display and keeps its window
 * bookkeeping (size, flags, events) for a window that is the whole screen.
 * Nothing is drawn through SDL; RT64 presents through VK_KHR_display itself.
 *
 * SDL_PS5_DISPLAY=WIDTHxHEIGHT in the environment sets the size the display
 * reports (default 1920x1080, which is also the size the window starts at).
 *
 * SPDX-License-Identifier: Zlib
 */
#include "../../SDL_internal.h"

#ifdef SDL_VIDEO_DRIVER_PS5

#include "../SDL_sysvideo.h"
#include "../../events/SDL_events_c.h"
#include "../../events/SDL_keyboard_c.h"
#include "../../events/SDL_mouse_c.h"

static int PS5_VideoInit(_THIS)
{
    SDL_DisplayMode mode;
    int w = 1920, h = 1080;
    const char *size = SDL_getenv("SDL_PS5_DISPLAY");

    if (size && SDL_sscanf(size, "%dx%d", &w, &h) != 2) {
        w = 1920;
        h = 1080;
    }
    SDL_zero(mode);
    mode.format = SDL_PIXELFORMAT_RGB888;
    mode.w = w;
    mode.h = h;
    mode.refresh_rate = 60;
    if (SDL_AddBasicVideoDisplay(&mode) < 0) {
        return -1;
    }
    SDL_AddDisplayMode(&_this->displays[0], &mode);
    return 0;
}

static void PS5_VideoQuit(_THIS)
{
}

static void PS5_PumpEvents(_THIS)
{
    /* The pads are read by the joystick driver */
}

static int PS5_CreateWindow(_THIS, SDL_Window *window)
{
    /* The window is the screen, and always has the pad's focus */
    SDL_SetMouseFocus(window);
    SDL_SetKeyboardFocus(window);
    return 0;
}

static void PS5_SetWindowPosition(_THIS, SDL_Window *window)
{
}

static void PS5_SetWindowSize(_THIS, SDL_Window *window)
{
    /* The size stays the display's */
}

static void PS5_SetWindowFullscreen(_THIS, SDL_Window *window, SDL_VideoDisplay *display, SDL_bool fullscreen)
{
}

static void PS5_DeleteDevice(SDL_VideoDevice *device)
{
    SDL_free(device);
}

static SDL_VideoDevice *PS5_CreateDevice(void)
{
    SDL_VideoDevice *device = (SDL_VideoDevice *)SDL_calloc(1, sizeof(SDL_VideoDevice));
    if (!device) {
        SDL_OutOfMemory();
        return NULL;
    }
    device->VideoInit = PS5_VideoInit;
    device->VideoQuit = PS5_VideoQuit;
    device->PumpEvents = PS5_PumpEvents;
    device->CreateSDLWindow = PS5_CreateWindow;
    device->SetWindowPosition = PS5_SetWindowPosition;
    device->SetWindowSize = PS5_SetWindowSize;
    device->SetWindowFullscreen = PS5_SetWindowFullscreen;
    device->free = PS5_DeleteDevice;
    return device;
}

VideoBootStrap PS5_bootstrap = {
    "ps5", "PlayStation 5 video driver",
    PS5_CreateDevice,
    NULL /* no ShowMessageBox */
};

#endif /* SDL_VIDEO_DRIVER_PS5 */
