import { getApp, hashApiKey, type AppRow } from './db';

export async function appResolver(c: any, next: () => Promise<void>): Promise<Response | void> {
  const appId = c.req.param('app_id');
  if (!appId) return c.text('app_id required', 400);
  const app = await getApp(c.env.DB, appId);
  if (!app) return c.text('app not found', 404);
  c.set('app', app);
  await next();
}

export async function appAuth(c: any, next: () => Promise<void>): Promise<Response | void> {
  const auth = c.req.header('authorization');
  if (!auth?.startsWith('Bearer ')) return c.text('forbidden', 403);
  const key = auth.slice(7);
  const app = c.get('app');
  if (!app) return c.text('app not found', 404);
  const hash = await hashApiKey(key);
  if (hash !== app.admin_key_hash) return c.text('forbidden', 403);
  await next();
}