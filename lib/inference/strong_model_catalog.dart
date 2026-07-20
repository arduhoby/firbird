import 'dart:convert';

class StrongModelDescriptor {
  const StrongModelDescriptor({
    required this.id,
    required this.version,
    required this.runtime,
    required this.modelUri,
    required this.modelBytes,
    required this.sha256,
    required this.license,
    required this.candidateScope,
    required this.candidatePolicy,
  });

  factory StrongModelDescriptor.fromJson(Map<String, Object?> json) {
    return StrongModelDescriptor(
      id: json['id']! as String,
      version: json['version']! as String,
      runtime: json['runtime']! as String,
      modelUri: Uri.parse(json['modelUri']! as String),
      modelBytes: json['modelBytes']! as int,
      sha256: json['sha256']! as String,
      license: json['license']! as String,
      candidateScope: json['candidateScope']! as String,
      candidatePolicy: json['candidatePolicy']! as String,
    );
  }

  final String id;
  final String version;
  final String runtime;
  final Uri modelUri;
  final int modelBytes;
  final String sha256;
  final String license;
  final String candidateScope;
  final String candidatePolicy;
}

StrongModelDescriptor parseStrongModelDescriptor(String source) {
  return StrongModelDescriptor.fromJson(
    jsonDecode(source) as Map<String, Object?>,
  );
}
