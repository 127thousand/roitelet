export interface AppRow {
  app_id: string;
  name: string;
  pubkey: string;
  admin_key_hash: string;
  min_store_version: string | null;
  created_at: number;
  updated_at: number;
}

export async function getApp(db: D1Database, appId: string): Promise<AppRow | null> {
  const result = await db.prepare('SELECT * FROM apps WHERE app_id = ?')
    .bind(appId)
    .first<AppRow>();
  return result ?? null;
}

export async function createApp(db: D1Database, app: { app_id: string; name: string; pubkey: string; admin_key_hash: string; min_store_version: string | null }): Promise<void> {
  await db.prepare(
    'INSERT INTO apps (app_id, name, pubkey, admin_key_hash, min_store_version) VALUES (?, ?, ?, ?, ?)'
  ).bind(app.app_id, app.name, app.pubkey, app.admin_key_hash, app.min_store_version ?? null).run();
}

export async function hashApiKey(key: string): Promise<string> {
  const data = new TextEncoder().encode(key);
  const hash = await crypto.subtle.digest('SHA-256', data);
  return Array.from(new Uint8Array(hash)).map(b => b.toString(16).padStart(2, '0')).join('');
}