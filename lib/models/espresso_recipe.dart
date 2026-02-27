import 'dart:convert';

/// 프로파일 모드: 전체 레시피에서 압력 또는 유량 중 하나로 통일
enum ProfileMode { pressure, flow }

/// 변곡점 (Stage 3+)
///
/// [duration]초 동안 [targetValue]를 가한다.
/// 고정 램프 속도(1 unit/s)로 목표에 도달 후 유지.
class ProfileWaypoint {
  double duration;     // 지속 시간 (s), 최소 1초
  double targetValue;  // 목표 압력(bar) 또는 유량(ml/s)

  ProfileWaypoint({
    required this.duration,
    required this.targetValue,
  });

  Map<String, dynamic> toJson() => {
        'duration': duration,
        'targetValue': targetValue,
      };

  factory ProfileWaypoint.fromJson(Map<String, dynamic> json) {
    return ProfileWaypoint(
      duration: (json['duration'] as num?)?.toDouble() ??
          (json['timeOffset'] as num?)?.toDouble() ??
          5.0,
      targetValue: (json['targetValue'] as num).toDouble(),
    );
  }

  ProfileWaypoint copyWith({
    double? duration,
    double? targetValue,
  }) {
    return ProfileWaypoint(
      duration: duration ?? this.duration,
      targetValue: targetValue ?? this.targetValue,
    );
  }
}

/// 에스프레소 레시피 데이터 모델
///
/// 모든 스테이지는 동일 파라미터: 시간(duration), 타깃.
/// "N초 동안 N bar를 가하라" — 고정 램프 속도(1 bar/s)로 목표 도달 후 유지.
/// 시간 우선: 지정 시간 내 미도달 시 현재 값에서 다음 스테이지로.
/// 마지막 스테이지는 종료 조건(endWeight/maxShotTime)까지 유지.
/// PI(Stage 1): 시간=0이면 비활성. 나머지 스테이지: 최소 1초.
class EspressoRecipe {
  final String id;
  String name;
  ProfileMode profileMode;

  // Pre-infusion (Stage 1) — 시간=0이면 비활성
  double preInfusionTime;       // 초 (0 = PI 비활성)
  double preInfusionTarget;     // bar 또는 ml/s

  // Extraction (Stage 2)
  double extractionTime;        // 초 (최소 1초)
  double extractionTarget;      // bar 또는 ml/s

  /// 변곡점 목록 (Stage 3+), 순서대로 실행
  List<ProfileWaypoint> waypoints;

  // Temperature
  double temperature; // ℃ (단일 고정)

  // End conditions
  double endWeight;   // g
  double maxShotTime; // s (안전장치)

  DateTime createdAt;
  DateTime updatedAt;

  EspressoRecipe({
    required this.id,
    this.name = 'New Recipe',
    this.profileMode = ProfileMode.pressure,
    this.preInfusionTime = 5.0,
    this.preInfusionTarget = 3.0,
    this.extractionTime = 5.0,
    this.extractionTarget = 9.0,
    List<ProfileWaypoint>? waypoints,
    this.temperature = 93.0,
    this.endWeight = 36.0,
    this.maxShotTime = 40.0,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : waypoints = waypoints ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  String get unitLabel =>
      profileMode == ProfileMode.pressure ? 'bar' : 'ml/s';

  double get yAxisMax =>
      profileMode == ProfileMode.pressure ? 15.0 : 10.0;

  bool get hasPreInfusion => preInfusionTime > 0;

  /// Extraction 시작 시각 = PI 종료 시각
  double get extractionStartTime => preInfusionTime;

  /// 최대 변곡점 수 (Stage 3~10 = 8개)
  bool get canAddWaypoint => waypoints.length < 8;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'profileMode': profileMode.index,
        'preInfusionTime': preInfusionTime,
        'preInfusionTarget': preInfusionTarget,
        'extractionTime': extractionTime,
        'extractionTarget': extractionTarget,
        'waypoints': waypoints.map((w) => w.toJson()).toList(),
        'temperature': temperature,
        'endWeight': endWeight,
        'maxShotTime': maxShotTime,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory EspressoRecipe.fromJson(Map<String, dynamic> json) {
    // Stage 기반 포맷에서 변환
    if (json.containsKey('stages')) {
      final stages = (json['stages'] as List<dynamic>)
          .map((s) => s as Map<String, dynamic>)
          .toList();
      return EspressoRecipe(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'New Recipe',
        profileMode: ProfileMode.values[json['profileMode'] as int? ?? 0],
        preInfusionTime: stages.isNotEmpty
            ? (stages[0]['duration'] as num).toDouble()
            : 5.0,
        preInfusionTarget: stages.isNotEmpty
            ? (stages[0]['target'] as num).toDouble()
            : 3.0,
        extractionTime: stages.length > 1
            ? (stages[1]['duration'] as num?)?.toDouble() ?? 5.0
            : 5.0,
        extractionTarget: stages.length > 1
            ? (stages[1]['target'] as num).toDouble()
            : 9.0,
        temperature: (json['temperature'] as num?)?.toDouble() ?? 93.0,
        endWeight: (json['endWeight'] as num?)?.toDouble() ?? 36.0,
        maxShotTime: (json['maxShotTime'] as num?)?.toDouble() ?? 40.0,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'] as String)
            : null,
      );
    }

    return EspressoRecipe(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'New Recipe',
      profileMode: ProfileMode.values[json['profileMode'] as int? ?? 0],
      preInfusionTime:
          (json['preInfusionTime'] as num?)?.toDouble() ?? 5.0,
      preInfusionTarget:
          (json['preInfusionTarget'] as num?)?.toDouble() ?? 3.0,
      extractionTime:
          (json['extractionTime'] as num?)?.toDouble() ?? 5.0,
      extractionTarget:
          (json['extractionTarget'] as num?)?.toDouble() ?? 9.0,
      waypoints: (json['waypoints'] as List<dynamic>?)
              ?.map((w) =>
                  ProfileWaypoint.fromJson(w as Map<String, dynamic>))
              .toList() ??
          [],
      temperature: (json['temperature'] as num?)?.toDouble() ?? 93.0,
      endWeight: (json['endWeight'] as num?)?.toDouble() ?? 36.0,
      maxShotTime: (json['maxShotTime'] as num?)?.toDouble() ?? 40.0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory EspressoRecipe.fromJsonString(String jsonString) {
    return EspressoRecipe.fromJson(
        jsonDecode(jsonString) as Map<String, dynamic>);
  }

  EspressoRecipe copyWith({
    String? name,
    ProfileMode? profileMode,
    double? preInfusionTime,
    double? preInfusionTarget,
    double? extractionTime,
    double? extractionTarget,
    List<ProfileWaypoint>? waypoints,
    double? temperature,
    double? endWeight,
    double? maxShotTime,
  }) {
    return EspressoRecipe(
      id: id,
      name: name ?? this.name,
      profileMode: profileMode ?? this.profileMode,
      preInfusionTime: preInfusionTime ?? this.preInfusionTime,
      preInfusionTarget: preInfusionTarget ?? this.preInfusionTarget,
      extractionTime: extractionTime ?? this.extractionTime,
      extractionTarget: extractionTarget ?? this.extractionTarget,
      waypoints: waypoints ??
          this.waypoints.map((w) => w.copyWith()).toList(),
      temperature: temperature ?? this.temperature,
      endWeight: endWeight ?? this.endWeight,
      maxShotTime: maxShotTime ?? this.maxShotTime,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
