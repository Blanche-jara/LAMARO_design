import 'dart:convert';

/// 프로파일 모드: 전체 레시피에서 압력 또는 유량 중 하나로 통일
enum ProfileMode { pressure, flow }

/// 램프 타입: 이전 노드에서 현재 노드까지의 커브 형태
enum RampType { linear, exponential }

/// 변곡점 노드 (Node 3+)
///
/// 그래프 상의 좌표점: ([time], [targetValue]).
/// [rampType]은 이전 노드에서 이 노드까지의 커브 형태.
class ProfileWaypoint {
  double time;         // 절대 시간 좌표 (s), X축
  double targetValue;  // 목표 압력(bar) 또는 유량(ml/s), Y축
  RampType rampType;   // 이전 노드 → 이 노드 커브 형태

  ProfileWaypoint({
    required this.time,
    required this.targetValue,
    this.rampType = RampType.linear,
  });

  Map<String, dynamic> toJson() => {
        'time': time,
        'targetValue': targetValue,
        'rampType': rampType.index,
      };

  factory ProfileWaypoint.fromJson(Map<String, dynamic> json) {
    return ProfileWaypoint(
      time: (json['time'] as num?)?.toDouble() ??
          (json['duration'] as num?)?.toDouble() ??
          (json['timeOffset'] as num?)?.toDouble() ??
          15.0,
      targetValue: (json['targetValue'] as num).toDouble(),
      rampType: RampType.values[json['rampType'] as int? ?? 0],
    );
  }

  ProfileWaypoint copyWith({
    double? time,
    double? targetValue,
    RampType? rampType,
  }) {
    return ProfileWaypoint(
      time: time ?? this.time,
      targetValue: targetValue ?? this.targetValue,
      rampType: rampType ?? this.rampType,
    );
  }
}

/// 에스프레소 레시피 데이터 모델
///
/// 각 노드는 그래프 상의 좌표점 (시간, 타깃).
/// "시간 5s, 타깃 9bar" = 5초 시점에 9bar 도달 = 좌표 (5, 9).
/// 노드 간 커브는 Lin/Exp 선택 가능.
/// 마지막 노드 이후 종료 조건(endWeight/maxShotTime)까지 유지.
/// PI(Node 1): 시간=0이면 비활성.
class EspressoRecipe {
  final String id;
  String name;
  ProfileMode profileMode;

  // Pre-infusion (Node 1) — 시간=0이면 비활성
  double preInfusionTime;       // 절대 시간 좌표 (s), 0 = PI 비활성
  double preInfusionTarget;     // bar 또는 ml/s
  RampType preInfusionRampType;

  // Extraction (Node 2)
  double extractionTime;        // 절대 시간 좌표 (s), >= piTime
  double extractionTarget;      // bar 또는 ml/s
  RampType extractionRampType;

  /// 변곡점 노드 목록 (Node 3+), 순서대로
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
    this.preInfusionRampType = RampType.linear,
    this.extractionTime = 10.0,
    this.extractionTarget = 9.0,
    this.extractionRampType = RampType.linear,
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

  /// 최대 변곡점 수 (Node 3~10 = 8개)
  bool get canAddWaypoint => waypoints.length < 8;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'profileMode': profileMode.index,
        'preInfusionTime': preInfusionTime,
        'preInfusionTarget': preInfusionTarget,
        'preInfusionRampType': preInfusionRampType.index,
        'extractionTime': extractionTime,
        'extractionTarget': extractionTarget,
        'extractionRampType': extractionRampType.index,
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
        preInfusionRampType: stages.isNotEmpty
            ? RampType.values[stages[0]['rampType'] as int? ?? 0]
            : RampType.linear,
        extractionTime: stages.length > 1
            ? (stages[1]['duration'] as num?)?.toDouble() ?? 10.0
            : 10.0,
        extractionTarget: stages.length > 1
            ? (stages[1]['target'] as num).toDouble()
            : 9.0,
        extractionRampType: stages.length > 1
            ? RampType.values[stages[1]['rampType'] as int? ?? 0]
            : RampType.linear,
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
      preInfusionRampType:
          RampType.values[json['preInfusionRampType'] as int? ?? 0],
      extractionTime:
          (json['extractionTime'] as num?)?.toDouble() ?? 10.0,
      extractionTarget:
          (json['extractionTarget'] as num?)?.toDouble() ?? 9.0,
      extractionRampType:
          RampType.values[json['extractionRampType'] as int? ?? 0],
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
    RampType? preInfusionRampType,
    double? extractionTime,
    double? extractionTarget,
    RampType? extractionRampType,
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
      preInfusionRampType: preInfusionRampType ?? this.preInfusionRampType,
      extractionTime: extractionTime ?? this.extractionTime,
      extractionTarget: extractionTarget ?? this.extractionTarget,
      extractionRampType: extractionRampType ?? this.extractionRampType,
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
