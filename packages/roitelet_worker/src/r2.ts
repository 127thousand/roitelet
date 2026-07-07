export interface Manifest {
  patch_number: number;
  evc_url: string;
  signature: string;
  hash: string;
  created_at: string;
}

export function manifestKey(appId: string, releaseVersion: string): string {
  return `manifest/${appId}/${releaseVersion}.json`;
}

export function evcKey(appId: string, releaseVersion: string, patchNumber: number): string {
  return `evc/${appId}/${releaseVersion}/${patchNumber}.evc`;
}