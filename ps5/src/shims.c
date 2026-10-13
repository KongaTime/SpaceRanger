/*
 * SpaceRanger for the PlayStation 5 - libc names no module a title loads exports.
 *
 * From PS5_Dusklight (griches), which found them. The SDK's stubs let these
 * link, but the import is null at run time and its first call jumps to address
 * 0. tools/link-title.sh binds each name to its ps5sr_ answer here (its `shims`
 * list must name every function below), and refuses a title that still
 * imports a name no loaded module exports.
 *
 * SPDX-License-Identifier: MIT
 */
#include <errno.h>

/* Nothing a title writes to is a terminal: its output goes to klog. */
int
ps5sr_isatty(int fd)
{
   (void)fd;
   errno = ENOTTY;
   return 0;
}

/* One user, and no privilege to drop (SDL asks whether the process is setuid). */
int
ps5sr_getresuid(unsigned *real, unsigned *effective, unsigned *saved)
{
   *real = *effective = *saved = 0;
   return 0;
}

int
ps5sr_getresgid(unsigned *real, unsigned *effective, unsigned *saved)
{
   *real = *effective = *saved = 0;
   return 0;
}

/* No list of loaded modules to walk. */
int
ps5sr_dl_iterate_phdr(int (*callback)(void *, unsigned long, void *), void *data)
{
   (void)callback;
   (void)data;
   return 0;
}

/* Files belong to no one in particular. */
int
ps5sr_fchown(int fd, unsigned owner, unsigned group)
{
   (void)fd;
   (void)owner;
   (void)group;
   return 0;
}

/* A title is one process: nothing can be started from it (SDL_OpenURL). */
int
ps5sr_fork(void)
{
   errno = ENOSYS;
   return -1;
}

int
ps5sr_vfork(void)
{
   errno = ENOSYS;
   return -1;
}

int
ps5sr_setsid(void)
{
   errno = ENOSYS;
   return -1;
}

/* FreeBSD's _PC_NAME_MAX and _PC_PATH_MAX; no other limit is known
 * (libc++'s std::filesystem asks). */
long
ps5sr_pathconf(const char *path, int name)
{
   (void)path;
   switch (name) {
   case 4:
      return 255;
   case 5:
      return 1024;
   default:
      errno = EINVAL;
      return -1;
   }
}

/* The network is not used: addresses have no names. */
int
ps5sr_getnameinfo(const void *address, unsigned length, char *host, unsigned host_size, char *service,
                  unsigned service_size, int flags)
{
   (void)address;
   (void)length;
   (void)host;
   (void)host_size;
   (void)service;
   (void)service_size;
   (void)flags;
   return 4; /* EAI_FAIL */
}

const char *
ps5sr_gai_strerror(int code)
{
   (void)code;
   return "name resolution is not available";
}

/* lstat does not work for a title (std::filesystem::symlink_status then reports
 * an occupied path, and creating a file there is refused). A title's folders
 * hold no symbolic links: stat answers the same. */
struct stat;
int stat(const char *path, struct stat *out);

int
ps5sr_lstat(const char *path, struct stat *out)
{
   return stat(path, out);
}

/* A title starts no programs (SDL_OpenURL). */
int
ps5sr_execlp(const char *file, const char *arg, ...)
{
   (void)file;
   (void)arg;
   errno = ENOSYS;
   return -1;
}

/* timegm: struct tm in UTC to seconds since 1970 (RT64's debugger plots ask);
 * the console's libc has mktime only. Days from the civil date as in Howard
 * Hinnant's days_from_civil. */
#include <time.h>

time_t
ps5sr_timegm(struct tm *tm)
{
   long long year = (long long)tm->tm_year + 1900;
   long long month = tm->tm_mon; /* 0..11, normalised below */
   year += month / 12;
   month %= 12;
   if (month < 0) {
      month += 12;
      year -= 1;
   }
   month += 1; /* 1..12 */
   const long long y = year - (month <= 2);
   const long long era = (y >= 0 ? y : y - 399) / 400;
   const long long yoe = y - era * 400;
   const long long doy = (153 * (month + (month > 2 ? -3 : 9)) + 2) / 5 + tm->tm_mday - 1;
   const long long doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
   const long long days = era * 146097 + doe - 719468;
   return (time_t)(days * 86400LL + tm->tm_hour * 3600LL + tm->tm_min * 60LL + tm->tm_sec);
}
