import 'package:equatable/equatable.dart';

enum RegionDownloadStatus {
  notDownloaded,
  downloading,
  extracting,
  downloaded,
  updateAvailable,
  failed,
}

class RegionModel extends Equatable {
  final String id;
  final String name;
  final String description;
  final List<double> bbox;
  final String downloadUrl;
  final int sizeBytes;
  final String version;
  final String? localVersion;
  final RegionDownloadStatus status;
  final double downloadProgress;
  final DateTime? downloadedAt;
  final String? localPath;
  final String? checksum;

  const RegionModel({
    required this.id,
    required this.name,
    required this.description,
    required this.bbox,
    required this.downloadUrl,
    required this.sizeBytes,
    required this.version,
    this.localVersion,
    this.status = RegionDownloadStatus.notDownloaded,
    this.downloadProgress = 0.0,
    this.downloadedAt,
    this.localPath,
    this.checksum,
  });

  bool get isDownloaded =>
      status == RegionDownloadStatus.downloaded ||
      status == RegionDownloadStatus.updateAvailable;

  bool get isDownloading =>
      status == RegionDownloadStatus.downloading ||
      status == RegionDownloadStatus.extracting;

  bool get hasUpdate => status == RegionDownloadStatus.updateAvailable;

  String get formattedSize {
    if (sizeBytes <= 0) return '0 MB';
    final mb = sizeBytes / (1024 * 1024);
    if (mb < 1.0) {
      final kb = sizeBytes / 1024;
      return '${kb.toStringAsFixed(1)} KB';
    }
    return '${mb.toStringAsFixed(1)} MB';
  }

  RegionModel copyWith({
    String? id,
    String? name,
    String? description,
    List<double>? bbox,
    String? downloadUrl,
    int? sizeBytes,
    String? version,
    String? localVersion,
    RegionDownloadStatus? status,
    double? downloadProgress,
    DateTime? downloadedAt,
    String? localPath,
    String? checksum,
  }) {
    return RegionModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      bbox: bbox ?? this.bbox,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      version: version ?? this.version,
      localVersion: localVersion ?? this.localVersion,
      status: status ?? this.status,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      localPath: localPath ?? this.localPath,
      checksum: checksum ?? this.checksum,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'bbox': bbox,
      'downloadUrl': downloadUrl,
      'sizeBytes': sizeBytes,
      'version': version,
      'localVersion': localVersion,
      'status': status.name,
      'downloadProgress': downloadProgress,
      'downloadedAt': downloadedAt?.toIso8601String(),
      'localPath': localPath,
      'checksum': checksum,
    };
  }

  factory RegionModel.fromMap(Map<String, dynamic> map) {
    return RegionModel(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      bbox: (map['bbox'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          const [],
      downloadUrl: map['downloadUrl'] as String? ?? '',
      sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
      version: map['version'] as String? ?? '1.0.0',
      localVersion: map['localVersion'] as String?,
      status: RegionDownloadStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => RegionDownloadStatus.notDownloaded,
      ),
      downloadProgress:
          (map['downloadProgress'] as num?)?.toDouble() ?? 0.0,
      downloadedAt: map['downloadedAt'] != null
          ? DateTime.tryParse(map['downloadedAt'] as String)
          : null,
      localPath: map['localPath'] as String?,
      checksum: map['checksum'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        bbox,
        downloadUrl,
        sizeBytes,
        version,
        localVersion,
        status,
        downloadProgress,
        downloadedAt,
        localPath,
        checksum,
      ];
}
