/*
 * SpaceRanger for the PlayStation 5 - what runs before the game's main.
 *
 * SpaceRanger's main is its own (src/stage79_first_vi_audio_wakeup.cpp), so
 * the console's start-up is a constructor: standard error into klog (each line
 * prefixed with the title's name) and the shell's splash dismissed. The
 * folder the game works in is its own (/app0, which is
 * /data/homebrew/<TITLE_ID>): main makes it the working directory.
 *
 * A title ends when main returns: the platform layer's catchReturnFromMain
 * asks the shell to close it (exit() would be reported as a crash).
 *
 * SPDX-License-Identifier: MIT
 */
#include "platform.h"

__attribute__((constructor)) static void
ps5_startup(void)
{
   platform_init(PS5_TITLE_NAME);
   say("SpaceRanger for the PlayStation 5: starting");
}
