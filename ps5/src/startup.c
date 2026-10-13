/*
 * SpaceRanger for the PlayStation 5 - what runs before the game's main.
 *
 * SpaceRanger's main is its own (src/stage79_first_vi_audio_wakeup.cpp), so
 * the console's start-up is a constructor: the title's log (klog and
 * spaceranger-log.txt in its folder, with crash reports: ps5/src/log.c) and
 * the shell's splash dismissed. This is platform_init's work, with the log
 * file added. The folder the game works in is its own (/app0, which is
 * /data/homebrew/<TITLE_ID>): main makes it the working directory.
 *
 * A title ends when main returns: the platform layer's catchReturnFromMain
 * asks the shell to close it (exit() would be reported as a crash).
 *
 * SPDX-License-Identifier: MIT
 */
#include "platform.h"

int sceSystemServiceHideSplashScreen(void);
void ps5sr_log_start(const char *prefix);

/* Priority 101: before every other constructor (the linker script sorts
 * prioritised ones first), so a crash in one of those is in the log */
__attribute__((constructor(101))) static void
ps5_startup(void)
{
   ps5sr_log_start(PS5_TITLE_NAME);
   say("SpaceRanger for the PlayStation 5: starting (log: /app0/spaceranger-log.txt)");
   /* The shell's splash covers the title's frames until it is dismissed. */
   say("dismissing the splash");
   say("splash dismissed: %d", sceSystemServiceHideSplashScreen());
}
