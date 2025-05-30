CREATE TABLE IF NOT EXISTS "schema_migrations" ("version" INTEGER PRIMARY KEY, "inserted_at" TEXT_DATETIME);
CREATE TABLE IF NOT EXISTS "heartbeats" ("time" REAL NOT NULL, "entity" TEXT NOT NULL, "type" TEXT NOT NULL, "category" TEXT, "project" TEXT, "branch" TEXT, "language" TEXT, "dependencies" TEXT, "lines" INTEGER, "lineno" INTEGER, "cursorpos" INTEGER, "is_write" INTEGER DEFAULT false NOT NULL, "editor" TEXT, "operating_system" TEXT, "machine_name" TEXT) STRICT;
CREATE INDEX "heartbeats_time_index" ON "heartbeats" ("time");
INSERT INTO schema_migrations VALUES(20220530124959,'2022-05-30T13:52:58');
