import 'package:equatable/equatable.dart';
import 'package:s_map/models/models.dart';

enum DownloadRegionStatus {
  initial,
  loading,
  loaded,
  downloading,
  success,
  error,
}

class DownloadRegionState extends Equatable {
  final DownloadRegionStatus status;
  final List<RegionModel> regions;
  final Map<String, double> progressMap;
  final String? currentlyDownloadingRegionId;
  final int totalStorageBytes;
  final String? errorMessage;
  final String? successMessage;

  const DownloadRegionState({
    this.status = DownloadRegionStatus.initial,
    this.regions = const [],
    this.progressMap = const {},
    this.currentlyDownloadingRegionId,
    this.totalStorageBytes = 0,
    this.errorMessage,
    this.successMessage,
  });

  bool get isInitial => status == DownloadRegionStatus.initial;
  bool get isLoading => status == DownloadRegionStatus.loading;
  bool get isLoaded => status == DownloadRegionStatus.loaded;
  bool get isDownloadingAny => currentlyDownloadingRegionId != null;
  bool get isSuccess => status == DownloadRegionStatus.success;
  bool get isError => status == DownloadRegionStatus.error;

  bool isDownloading(String regionId) =>
      currentlyDownloadingRegionId == regionId ||
      (progressMap.containsKey(regionId) && (progressMap[regionId] ?? 0.0) < 1.0);

  double getProgress(String regionId) => progressMap[regionId] ?? 0.0;

  RegionModel? getRegion(String regionId) {
    try {
      return regions.firstWhere((r) => r.id == regionId);
    } catch (_) {
      return null;
    }
  }

  int get downloadedRegionsCount =>
      regions.where((r) => r.isDownloaded).length;

  String get formattedTotalStorage {
    if (totalStorageBytes <= 0) return '0 MB';
    final mb = totalStorageBytes / (1024 * 1024);
    if (mb >= 1024.0) {
      final gb = mb / 1024.0;
      return '${gb.toStringAsFixed(2)} GB';
    }
    return '${mb.toStringAsFixed(1)} MB';
  }

  DownloadRegionState copyWith({
    DownloadRegionStatus? status,
    List<RegionModel>? regions,
    Map<String, double>? progressMap,
    String? currentlyDownloadingRegionId,
    bool clearDownloadingRegion = false,
    int? totalStorageBytes,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return DownloadRegionState(
      status: status ?? this.status,
      regions: regions ?? this.regions,
      progressMap: progressMap ?? this.progressMap,
      currentlyDownloadingRegionId: clearDownloadingRegion
          ? null
          : (currentlyDownloadingRegionId ?? this.currentlyDownloadingRegionId),
      totalStorageBytes: totalStorageBytes ?? this.totalStorageBytes,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        regions,
        progressMap,
        currentlyDownloadingRegionId,
        totalStorageBytes,
        errorMessage,
        successMessage,
      ];
}
