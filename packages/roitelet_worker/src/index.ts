import { manifestKey, evcKey } from './r2';
import { getApp, createApp, hashApiKey } from './db';

interface Env {
  ROITELET_BUCKET: R2Bucket;
  ROITELET_META: KVNamespace;
  DB: D1Database;
  ADMIN_KEY: string;
  PUBLIC_BASE: string;
}

export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    const url = new URL(req.url);

    // --- App registration (super-admin) ---
    // POST /admin/apps
    if (req.method === 'POST' && url.pathname === '/admin/apps') {
      const masterKey = req.headers.get('authorization');
      if (masterKey !== `Bearer ${env.ADMIN_KEY ?? ''}`) {
        return new Response('forbidden', { status: 403 });
      }
      const body = await req.json() as {
        app_id: string; name: string; pubkey: string; admin_key: string;
      };
      if (!body.app_id || !body.name || !body.pubkey || !body.admin_key) {
        return new Response('missing fields', { status: 400 });
      }
      const hash = await hashApiKey(body.admin_key);
      await createApp(env.DB, {
        app_id: body.app_id,
        name: body.name,
        pubkey: body.pubkey,
        admin_key_hash: hash,
        min_store_version: null,
      });
      return Response.json({ ok: true, app_id: body.app_id });
    }

    // --- Public GET endpoints ---
    if (req.method === 'GET') {
      // GET /v1/:app_id/manifest/:release_version
      const manifestMatch = url.pathname.match(/^\/v1\/([^/]+)\/manifest\/([^/]+)$/);
      if (manifestMatch) {
        const [, appId, relVer] = manifestMatch;
        const obj = await env.ROITELET_BUCKET.get(manifestKey(appId, relVer));
        if (obj === null) return new Response(null, { status: 204 });
        return new Response(obj.body, {
          headers: { 'content-type': 'application/json' },
        });
      }

      // GET /v1/:app_id/evc/:release_version/:patch_number.evc
      const evcMatch = url.pathname.match(/^\/v1\/([^/]+)\/evc\/([^/]+)\/(\d+)\.evc$/);
      if (evcMatch) {
        const [, appId, relVer, pnStr] = evcMatch;
        const obj = await env.ROITELET_BUCKET.get(evcKey(appId, relVer, parseInt(pnStr, 10)));
        if (obj === null) return new Response('not found', { status: 404 });
        return new Response(obj.body, {
          headers: {
            'content-type': 'application/octet-stream',
            'cache-control': 'public, max-age=3600',
          },
        });
      }

      // GET /v1/:app_id/translations/manifest/:release_version
      const transManifestMatch = url.pathname.match(/^\/v1\/([^/]+)\/translations\/manifest\/([^/]+)$/);
      if (transManifestMatch) {
        const [, appId, relVer] = transManifestMatch;
        const obj = await env.ROITELET_BUCKET.get(`translations/manifest/${appId}/${relVer}.json`);
        if (obj === null) return new Response(null, { status: 204 });
        return new Response(obj.body, {
          headers: { 'content-type': 'application/json' },
        });
      }

      // GET /v1/:app_id/translations/:release_version/:locale
      const transMatch = url.pathname.match(/^\/v1\/([^/]+)\/translations\/([^/]+)\/([^/]+)$/);
      if (transMatch) {
        const [, appId, relVer, locale] = transMatch;
        const obj = await env.ROITELET_BUCKET.get(`translations/${appId}/${relVer}/${locale}.json`);
        if (obj === null) return new Response(null, { status: 204 });
        return new Response(obj.body, {
          headers: { 'content-type': 'application/json' },
        });
      }
    }

    // --- Admin POST endpoints (per-app auth) ---
    if (req.method === 'POST') {
      // POST /admin/v1/:app_id/patch
      const adminPatchMatch = url.pathname.match(/^\/admin\/v1\/([^/]+)\/patch$/);
      if (adminPatchMatch) {
        const [, appId] = adminPatchMatch;
        const app = await getApp(env.DB, appId);
        if (!app) return new Response('app not found', { status: 404 });
        const auth = req.headers.get('authorization');
        if (!auth?.startsWith('Bearer ')) return new Response('forbidden', { status: 403 });
        const hash = await hashApiKey(auth.slice(7));
        if (hash !== app.admin_key_hash) return new Response('forbidden', { status: 403 });

        const form = await req.formData();
        const relVer = form.get('release_version') as string;
        const patchNumber = parseInt(form.get('patch_number') as string, 10);
        const signature = form.get('signature') as string;
        const hashField = form.get('hash') as string;
        const file = form.get('file') as unknown as File;
        if (!relVer || !patchNumber || !signature || !hashField || !file) {
          return new Response('missing fields', { status: 400 });
        }
        const bytes = await file.arrayBuffer();
        await env.ROITELET_BUCKET.put(
          evcKey(appId, relVer, patchNumber),
          bytes,
          { httpMetadata: { contentType: 'application/octet-stream' } },
        );
        const manifest = {
          patch_number: patchNumber,
          evc_url: `${env.PUBLIC_BASE}/v1/${appId}/evc/${relVer}/${patchNumber}.evc`,
          signature,
          hash: hashField,
          created_at: new Date().toISOString(),
        };
        await env.ROITELET_BUCKET.put(manifestKey(appId, relVer), JSON.stringify(manifest), {
          httpMetadata: { contentType: 'application/json' },
        });
        return Response.json(manifest);
      }

      // POST /admin/v1/:app_id/translate
      const adminTransMatch = url.pathname.match(/^\/admin\/v1\/([^/]+)\/translate$/);
      if (adminTransMatch) {
        const [, appId] = adminTransMatch;
        const app = await getApp(env.DB, appId);
        if (!app) return new Response('app not found', { status: 404 });
        const auth = req.headers.get('authorization');
        if (!auth?.startsWith('Bearer ')) return new Response('forbidden', { status: 403 });
        const hash = await hashApiKey(auth.slice(7));
        if (hash !== app.admin_key_hash) return new Response('forbidden', { status: 403 });

        const form = await req.formData();
        const relVer = form.get('release_version') as string;
        const locale = form.get('locale') as string;
        const signature = form.get('signature') as string;
        const hashField = form.get('hash') as string;
        const file = form.get('file') as unknown as File;
        if (!relVer || !locale || !signature || !hashField || !file) {
          return new Response('missing fields', { status: 400 });
        }
        const bytes = await file.arrayBuffer();
        await env.ROITELET_BUCKET.put(
          `translations/${appId}/${relVer}/${locale}.json`,
          bytes,
          { httpMetadata: { contentType: 'application/json' } },
        );
        const manifestKey2 = `translations/manifest/${appId}/${relVer}.json`;
        const existing = await env.ROITELET_BUCKET.get(manifestKey2);
        let manifest: Record<string, any> = {};
        if (existing !== null) manifest = await existing.json();
        manifest[locale] = {
          url: `${env.PUBLIC_BASE}/v1/${appId}/translations/${relVer}/${locale}.json`,
          signature,
          hash: hashField,
          updated_at: new Date().toISOString(),
        };
        await env.ROITELET_BUCKET.put(manifestKey2, JSON.stringify(manifest), {
          httpMetadata: { contentType: 'application/json' },
        });
        return Response.json(manifest);
      }
    }

    return new Response('not found', { status: 404 });
  },
};