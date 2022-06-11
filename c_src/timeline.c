#include "timeline.h"

#include <stdarg.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "../deps/exqlite/c_src/sqlite3ext.h"

SQLITE_EXTENSION_INIT1

// copied from https://github.com/jwerle/asprintf.c/blob/master/asprintf.c
static int vafmt(char **str, const char *fmt, va_list args) {
  int size = 0;
  va_list tmpa;

  // copy
  va_copy(tmpa, args);

  // apply variadic arguments to
  // sprintf with format to get size
  size = vsnprintf(NULL, 0, fmt, tmpa);

  // toss args
  va_end(tmpa);

  // return -1 to be compliant if
  // size is less than 0
  if (size < 0) {
    return -1;
  }

  // alloc with size plus 1 for `\0'
  *str = (char *)sqlite3_malloc(size + 1);

  // return -1 to be compliant
  // if pointer is `NULL'
  if (NULL == *str) {
    return -1;
  }

  // format string with original
  // variadic arguments and set new size
  size = vsprintf(*str, fmt, args);
  return size;
}

static int fmt(char **str, const char *fmt, ...) {
  int size = 0;
  va_list args;

  // init variadic argumens
  va_start(args, fmt);

  // format and get size
  size = vafmt(str, fmt, args);

  // toss args
  va_end(args);

  return size;
}

// TIMELINE

typedef struct timeline {
  int inited1;
  int inited2;
  sqlite3_value *prev_project_value;
  char *prev_project;
  double prev_time;
  double prev_from;
  char *csv;
} timeline;

static int timeline_csv_append(timeline *t, double time) {
  char *row;

  int from = t->prev_from;
  int to = time;

  // TODO escape project from commas? are commas allowed in folder names?
  int err = fmt(&row, "%s,%d,%d\n", t->prev_project, from, to);
  if (err < 0) return err;

  if (t->inited2 != 1) {
    t->csv = row;
    t->inited2 = 1;
  } else {
    t->csv = sqlite3_realloc(t->csv, strlen(t->csv) + strlen(row) + 1);
    strcat(t->csv, row);
    sqlite3_free(row);
  }

  return 0;
}

static int timeline_add(timeline *t, double time,
                        sqlite3_value *project_value) {
  if (t->inited1 != 1) {
    t->prev_time = time;
    t->prev_from = time;

    t->prev_project_value = sqlite3_value_dup(project_value);
    if (t->prev_project_value == NULL &&
        sqlite3_value_type(project_value) != SQLITE_NULL) {
      return -1;
    }

    // TODO check types
    t->prev_project = (char *)sqlite3_value_text(t->prev_project_value);
    t->inited1 = 1;
    return 0;
  }

  double diff = time - t->prev_time;
  // TODO check types
  char *project = (char *)sqlite3_value_text(project_value);
  int project_changed = (strcmp(t->prev_project, project) != 0);

  if (diff < 300) {
    if (project_changed) {
      if (timeline_csv_append(t, time) < 0) return -1;
      t->prev_from = time;
    }
  } else {
    if (timeline_csv_append(t, t->prev_time) < 0) return -1;
    t->prev_from = time;
  }

  if (project_changed) {
    sqlite3_value_free(t->prev_project_value);

    t->prev_project_value = sqlite3_value_dup(project_value);
    if (t->prev_project_value == NULL &&
        sqlite3_value_type(project_value) != SQLITE_NULL) {
      return -1;
    }

    // TODO check types
    t->prev_project = (char *)sqlite3_value_text(t->prev_project_value);
  }

  t->prev_time = time;

  return 0;
}

static int timeline_finish(timeline *t) {
  if (t->prev_project != NULL) {
    int err = timeline_csv_append(t, t->prev_time);
    if (err < 0) return err;
  }

  return 0;
}

static void timeline_free(timeline *t) {
  if (t->prev_project_value != NULL) sqlite3_value_free(t->prev_project_value);
  if (t->csv != NULL) sqlite3_free(t->csv);
}

// SQLITE CALLBACKS

static void timeline_step(sqlite3_context *ctx, int argc,
                          sqlite3_value **argv) {
  (void)(argc);
  timeline *t = (timeline *)sqlite3_aggregate_context(ctx, sizeof(timeline));

  if (t == NULL) {
    sqlite3_result_error_nomem(ctx);
    return;
  }

  // TODO check types
  double time = sqlite3_value_double(argv[0]);

  if (timeline_add(t, time, argv[1]) < 0) {
    sqlite3_result_error_nomem(ctx);
    timeline_free(t);
    return;
  }
}

static void timeline_final(sqlite3_context *ctx) {
  timeline *t = (timeline *)sqlite3_aggregate_context(ctx, sizeof(timeline));

  if (t == NULL) {
    sqlite3_result_error_nomem(ctx);
    return;
  }

  if (timeline_finish(t) < 0) {
    sqlite3_result_error_nomem(ctx);
    timeline_free(t);
    return;
  }

  sqlite3_result_text(ctx, t->csv, -1, SQLITE_TRANSIENT);
  timeline_free(t);
}

int sqlite3_extension_init(sqlite3 *db, char **pzErrMsg,
                           const sqlite3_api_routines *pApi) {
  (void)(pzErrMsg);
  SQLITE_EXTENSION_INIT2(pApi);

  //
  // Examples:
  //
  // `select timeline_csv(time, project) from heartbeats where time > ?;`
  // `select timeline_csv(time, project) from heartbeats order by time;`
  //
  // Notes:
  //
  // - need to force sqlite order by time somehow, can be done by time pkey,
  // filtering or ordering by time
  //
  // `select timeline_csv(time, project) from heartbeats;`
  //   would produce invalid results as heartbeats
  //   wouldn't be ordered by time
  //

  sqlite3_create_function(db, "timeline_csv", 2, SQLITE_UTF8, 0, 0,
                          timeline_step, timeline_final);

  return SQLITE_OK;
}
