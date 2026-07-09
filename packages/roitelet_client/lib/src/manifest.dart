class PatchManifest {
  final int patchNumber;
  final String evcUrl;
  final String signature;
  final String hash;
  final DateTime createdAt;
  final String? minStoreVersion;

  PatchManifest({
    required this.patchNumber,
    required this.evcUrl,
    required this.signature,
    required this.hash,
    required this.createdAt,
    this.minStoreVersion,
  });

  factory PatchManifest.fromJson(Map<String, dynamic> json) {
    final pn = json['patch_number'];
    final url = json['evc_url'];
    final sig = json['signature'];
    final hash = json['hash'];
    final created = json['created_at'];
    if (pn is! int || url is! String || sig is! String || hash is! String || created is! String) {
      throw FormatException('PatchManifest: missing or invalid fields');
    }
    return PatchManifest(
      patchNumber: pn,
      evcUrl: url,
      signature: sig,
      hash: hash,
      createdAt: DateTime.parse(created),
      minStoreVersion: json['min_store_version'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'patch_number': patchNumber,
        'evc_url': evcUrl,
        'signature': signature,
        'hash': hash,
        'created_at': createdAt.toIso8601String(),
        if (minStoreVersion != null) 'min_store_version': minStoreVersion!,
      };
}