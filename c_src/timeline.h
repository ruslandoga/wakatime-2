#ifndef TIMELINE_H
#define TIMELINE_H

#include "../deps/exqlite/c_src/sqlite3ext.h"

int sqlite3_extension_init(sqlite3 *db, char **pzErrMsg,
                           const sqlite3_api_routines *pApi);

#endif
