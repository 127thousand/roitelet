import { Manifest, manifestKey, evcKey } from './r2';

interface Env {
  ROITELET_BUCKET: R2Bucket;
  ROITELET_META: KVNamespace;
  ADMIN_KEY: string;
  PUBLIC_BASE: string;
}

export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    const url = new URL(req.url);

    if (req.method === 'GET') {
      const manifestMatch = url.pathname.match(/^\/v1\/manifest\/([^/]+)\/([^/]+)$/);
      if (manifestMatch) {
        const [, appId, relVer] = manifestMatch;
        const obj = await env.ROITELET_BUCKET.get(manifestKey(appId, relVer));
        if (obj === null) return new Response(null, { status: 204 });
        return new Response(obj.body, {
          headers: { 'content-type': 'application/json' },
        });
      }

      const evcMatch = url.pathname.match(/^\/v1\/evc\/([^/]+)\/([^/]+)\/(\d+)\.evc$/);
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
    }

    if (req.method === 'POST' && url.pathname === '/v1/admin/patch') {
      const auth = req.headers.get('authorization');
      if (auth !== `Bearer ${env.ADMIN_KEY}`) {
        return new Response('forbidden', { status: 403 });
      }
      const form = await req.formData();
      const appId = form.get('app_id') as string;
      const relVer = form.get('release_version') as string;
      const patchNumber = parseInt(form.get('patch_number') as string, 10);
      const signature = form.get('signature') as string;
      const hash = form.get('hash') as string;
      const file = form.get('file') as unknown as File;
      if (!appId || !relVer || !patchNumber || !signature || !hash || !file) {
        return new Response('missing fields', { status: 400 });
      }
      const bytes = await file.arrayBuffer();
      await env.ROITELET_BUCKET.put(
        evcKey(appId, relVer, patchNumber),
        bytes,
        { httpMetadata: { contentType: 'application/octet-stream' } },
      );
      const manifest: Manifest = {
        patch_number: patchNumber,
        evc_url: `${env.PUBLIC_BASE}/v1/evc/${appId}/${relVer}/${patchNumber}.evc`,
        signature,
        hash,
        created_at: new Date().toISOString(),
      };
      await env.ROITELET_BUCKET.put(manifestKey(appId, relVer), JSON.stringify(manifest), {
        httpMetadata: { contentType: 'application/json' },
      });
      return Response.json(manifest);
    }

    return new Response('not found', { status: 404 });
  },
};