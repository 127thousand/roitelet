class PatchManifest {
  final int patchNumber;
  final String evcUrl;
  final String signature;     // base64 ed25519 signature of the .evc bytes
  final String hash;          // hex sha256 of the .evc bytes
  final DateTime createdAt;

  PatchManifest({
    required this.patchNumber,
    required this.evcUrl,
    required this.signature,
    required this.hash,
    required this.createdAt,
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
    );
  }

  Map<String, dynamic> toJson() => {
        'patch_number': patchNumber,
        'evc_url': evcUrl,
        'signature': signature,
        'hash': hash,
        'created_at': createdAt.toIso8601String(),
      };
}