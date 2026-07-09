CREATE TABLE IF NOT EXISTS apps (
  app_id          TEXT PRIMARY KEY,
  name            TEXT NOT NULL,
  pubkey          TEXT NOT NULL,
  admin_key_hash  TEXT NOT NULL,
  min_store_version TEXT,
  created_at      INTEGER NOT NULL DEFAULT (unixepoch()),
  updated_at      INTEGER NOT NULL DEFAULT (unixepoch())
);