/*
 * SpaceRanger for the PlayStation 5 - the title's log: klog and a file.
 *
 * Everything the title writes to standard output or standard error goes to
 * spaceranger-log.txt in the title's folder (/data/homebrew/<TITLE_ID>/),
 * readable over FTP. A title may not dup2, so the streams themselves are
 * moved to the file, unbuffered: every line is in the file before the program
 * goes on, so the last line written before a title dies is there. (A pipe
 * read by a thread, as the platform layer's klog capture does, loses what is
 * still in the pipe when the title dies.)
 *
 * main is wrapped (--wrap=main in ps5/tools/link-title.sh) to log when it
 * starts and what it returns, and a thread logs "alive: N s" every five
 * seconds, which tells a hang from a crash.
 *
 * A fatal signal (a crash, abort()) writes its report straight to the file:
 * the signal, the faulting address and instruction, and a frame-pointer walk
 * of the stack, as offsets into the linked ELF (build-ps5/SpaceRanger):
 *   llvm-addr2line -f -C -e build-ps5/SpaceRanger <offset>...
 * exit() called anywhere but at the end of main is logged too: on the console
 * it ends the title as a crash would.
 *
 * SPDX-License-Identifier: MIT
 */
#include "platform.h"

#include <ps5platform/context.h>

#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <signal.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define LOG_PATH "/app0/spaceranger-log.txt"

static int log_fd = -1;
extern char __ehdr_start; /* the start of the title's image, from the linker */

/* ------------------------------------------------- async-signal-safe output */

static void
raw_write(const char *text)
{
   if (log_fd >= 0)
      (void)write(log_fd, text, strlen(text));
}

static void
raw_hex(const char *label, uint64_t value)
{
   char buffer[64];
   size_t at = 0;
   while (*label && at < 40)
      buffer[at++] = *label++;
   buffer[at++] = '0';
   buffer[at++] = 'x';
   for (int shift = 60; shift >= 0; shift -= 4)
      buffer[at++] = "0123456789abcdef"[(value >> shift) & 0xf];
   buffer[at] = '\0';
   raw_write(buffer);
}

/* --------------------------------------------------------------- the tee */

static void *
log_alive(void *unused)
{
   (void)unused;
   for (unsigned seconds = 5;; seconds += 5) {
      sleep(5);
      fprintf(stderr, "alive: %u s\n", seconds);
   }
   return NULL;
}

/* main, as the CRT calls it (--wrap=main) */
int __real_main(int argc, char **argv, char **envp);

int
__wrap_main(int argc, char **argv, char **envp)
{
   fprintf(stderr, "==== SpaceRanger: static constructors done, main starts\n");
   const int status = __real_main(argc, argv, envp);
   fprintf(stderr, "==== SpaceRanger: main returned %d\n", status);
   return status;
}

/* ------------------------------------------------------- the crash report */

static void
fatal_signal(int number, siginfo_t *info, void *context)
{
   const ucontext_t *uc = (const ucontext_t *)context;
   raw_write("\n==== SpaceRanger: fatal signal ");
   char digits[8] = {0};
   digits[0] = (char)('0' + (number / 10) % 10);
   digits[1] = (char)('0' + number % 10);
   raw_write(digits);
   raw_write(number == SIGSEGV   ? " (SIGSEGV)"
             : number == SIGBUS  ? " (SIGBUS)"
             : number == SIGILL  ? " (SIGILL)"
             : number == SIGFPE  ? " (SIGFPE)"
             : number == SIGABRT ? " (SIGABRT, abort())"
                                 : "");
   raw_write("\n");
   const uint64_t base = (uint64_t)(uintptr_t)&__ehdr_start;
   raw_hex("image base      ", base);
   raw_write("\n");
   raw_hex("fault address   ", (uint64_t)(uintptr_t)info->si_addr);
   raw_write("\n");
   const uint64_t rip = (uint64_t)uc->uc_mcontext.mc_rip;
   raw_hex("rip             ", rip);
   raw_hex("  offset ", rip - base);
   raw_write("\n");
   raw_hex("rsp             ", (uint64_t)uc->uc_mcontext.mc_rsp);
   raw_write("\n");
   raw_write("stack (offsets into build-ps5/SpaceRanger, for llvm-addr2line -f -C -e):\n");
   raw_hex("  ", rip - base);
   raw_write("\n");
   /* Frame pointers: every unit is built with -fno-omit-frame-pointer */
   const uint64_t *frame = (const uint64_t *)(uintptr_t)uc->uc_mcontext.mc_rbp;
   const uint64_t stack = (uint64_t)uc->uc_mcontext.mc_rsp;
   for (int depth = 0; depth < 48 && frame != NULL; depth++) {
      const uint64_t at = (uint64_t)(uintptr_t)frame;
      if ((at & 7) != 0 || at < stack || at - stack > (64u << 20))
         break;
      const uint64_t return_address = frame[1];
      if (return_address < base)
         break;
      raw_hex("  ", return_address - base);
      raw_write("\n");
      const uint64_t *next = (const uint64_t *)(uintptr_t)frame[0];
      if (next <= frame)
         break;
      frame = next;
   }
   raw_write("==== end of report\n");
   if (log_fd >= 0)
      (void)fsync(log_fd);
   /* The console's own handling (its crash report) from here */
   signal(number, SIG_DFL);
   raise(number);
}

static void
log_exit(void)
{
   /* main returning ends the title through catchReturnFromMain, not exit():
    * an exit() handler running means something called exit() */
   fflush(NULL);
   raw_write("==== SpaceRanger: exit() was called (the console reports it as a crash)\n");
   if (log_fd >= 0)
      (void)fsync(log_fd);
}

void
ps5sr_log_start(const char *prefix)
{
   (void)prefix;
   log_fd = open(LOG_PATH, O_WRONLY | O_CREAT | O_TRUNC, 0666);

   if (log_fd >= 0) {
      FILE *stream = fdopen(log_fd, "a");
      if (stream != NULL) {
         setvbuf(stream, NULL, _IONBF, 0);
         stderr = stream;
         stdout = stream;
      }
   }
   pthread_t thread;
   if (pthread_create(&thread, NULL, log_alive, NULL) == 0)
      pthread_detach(thread);

   static uint8_t alternate_stack[128 * 1024];
   stack_t alternate = {0};
   alternate.ss_sp = alternate_stack;
   alternate.ss_size = sizeof(alternate_stack);
   (void)sigaltstack(&alternate, NULL);
   struct sigaction action;
   memset(&action, 0, sizeof(action));
   action.sa_sigaction = fatal_signal;
   action.sa_flags = SA_SIGINFO | SA_ONSTACK | SA_RESETHAND;
   sigemptyset(&action.sa_mask);
   const int signals[] = {SIGSEGV, SIGBUS, SIGILL, SIGFPE, SIGABRT};
   for (size_t i = 0; i < sizeof(signals) / sizeof(signals[0]); i++)
      (void)sigaction(signals[i], &action, NULL);
   atexit(log_exit);
}
