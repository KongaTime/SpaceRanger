/*
 * SpaceRanger for the PlayStation 5 - SDL2's audio driver for the console.
 *
 * Ported to SDL2 from PS5_Dusklight's SDL3 driver (griches). One playback
 * device: an AudioOut main port, 48 kHz stereo 16-bit, a grain of 256 frames.
 * sceAudioOutOutput blocks while the console plays the grain before, which
 * paces SDL's audio thread. SDL converts whatever the program asks for
 * (SpaceRanger's bridge asks for float) to this format.
 *
 * SPDX-License-Identifier: Zlib
 */
#include "../../SDL_internal.h"

#ifdef SDL_AUDIO_DRIVER_PS5

#include "SDL_audio.h"
#include "SDL_cpuinfo.h"
#include "../SDL_audio_c.h"
#include "../SDL_sysaudio.h"

/* The device each driver function gets (SDL_sysaudio.h leaves _THIS undefined) */
#define _THIS SDL_AudioDevice *_this

int sceAudioOutInit(void);
int sceAudioOutOpen(int32_t user, int32_t type, int32_t index, uint32_t grain, uint32_t rate, uint32_t format);
int sceAudioOutOutput(int32_t port, const void *samples);
int sceAudioOutClose(int32_t port);

#define PS5_AUDIO_GRAIN               256
#define PS5_AUDIO_ALREADY_INITIALISED ((int)0x8026000e)
#define PS5_AUDIO_USER_SYSTEM         0xff
#define PS5_AUDIO_PORT_MAIN           0
#define PS5_AUDIO_FORMAT_S16_STEREO   1

struct SDL_PrivateAudioData
{
    int port;
    Uint8 *buffer;
};

static int PS5AUDIO_OpenDevice(_THIS, const char *devname)
{
    int init;

    _this->hidden = (struct SDL_PrivateAudioData *)SDL_calloc(1, sizeof(*_this->hidden));
    if (!_this->hidden) {
        return SDL_OutOfMemory();
    }
    _this->hidden->port = -1;

    _this->spec.format = AUDIO_S16LSB;
    _this->spec.channels = 2;
    _this->spec.freq = 48000;
    _this->spec.samples = PS5_AUDIO_GRAIN;
    SDL_CalculateAudioSpec(&_this->spec);

    _this->hidden->buffer = (Uint8 *)SDL_SIMDAlloc(_this->spec.size);
    if (!_this->hidden->buffer) {
        return SDL_OutOfMemory();
    }
    SDL_memset(_this->hidden->buffer, 0, _this->spec.size);

    init = sceAudioOutInit();
    if (init < 0 && init != PS5_AUDIO_ALREADY_INITIALISED) {
        return SDL_SetError("sceAudioOutInit: 0x%08x", (unsigned)init);
    }
    _this->hidden->port = sceAudioOutOpen(PS5_AUDIO_USER_SYSTEM, PS5_AUDIO_PORT_MAIN, 0, PS5_AUDIO_GRAIN, 48000,
                                         PS5_AUDIO_FORMAT_S16_STEREO);
    if (_this->hidden->port < 0) {
        return SDL_SetError("sceAudioOutOpen: 0x%08x", (unsigned)_this->hidden->port);
    }
    return 0;
}

static void PS5AUDIO_PlayDevice(_THIS)
{
    (void)sceAudioOutOutput(_this->hidden->port, _this->hidden->buffer);
}

static void PS5AUDIO_WaitDevice(_THIS)
{
    /* PlayDevice blocks */
}

static Uint8 *PS5AUDIO_GetDeviceBuf(_THIS)
{
    return _this->hidden->buffer;
}

static void PS5AUDIO_CloseDevice(_THIS)
{
    if (_this->hidden) {
        if (_this->hidden->port >= 0) {
            (void)sceAudioOutOutput(_this->hidden->port, NULL); /* drain */
            (void)sceAudioOutClose(_this->hidden->port);
        }
        SDL_SIMDFree(_this->hidden->buffer);
        SDL_free(_this->hidden);
        _this->hidden = NULL;
    }
}

static SDL_bool PS5AUDIO_Init(SDL_AudioDriverImpl *impl)
{
    impl->OpenDevice = PS5AUDIO_OpenDevice;
    impl->PlayDevice = PS5AUDIO_PlayDevice;
    impl->WaitDevice = PS5AUDIO_WaitDevice;
    impl->GetDeviceBuf = PS5AUDIO_GetDeviceBuf;
    impl->CloseDevice = PS5AUDIO_CloseDevice;
    impl->OnlyHasDefaultOutputDevice = SDL_TRUE;
    return SDL_TRUE; /* this audio target is available. */
}

AudioBootStrap PS5AUDIO_bootstrap = {
    "ps5", "PlayStation 5 audio driver", PS5AUDIO_Init, SDL_FALSE
};

#endif /* SDL_AUDIO_DRIVER_PS5 */
