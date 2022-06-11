#ifndef TIMELINE_FMT_H
#define TIMELINE_FMT_H

#include <stdarg.h>

int vafmt(char **str, const char *fmt, va_list args);
int fmt(char **str, const char *fmt, ...);

#endif
