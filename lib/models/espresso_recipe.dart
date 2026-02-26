import 'dart:convert';

/// 프로파일 모드: 전체 레시피에서 압력 또는 유량 중 하나로 통일
enum ProfileMode { pressure, flow }

/// 램프 타입: 목표값까지 도달하는 커브 형태
enum RampType { linear, exponential }

/// Extraction 구간 내 변곡점 (waypoint)
///
/// Extraction 시작 후 [timeOffset]초에 목표값을 [targetValue]로 변경.
/// 변곡점 간 보간은 [rampType]에 따라 linear 또는 exponential.
class ProfileWaypoint {
  double timeOffset;   // Extraction 시작 기준 경과 시간 (s)
  double targetValue;  // 목표 압력(bar) 또는 유량(ml/s)
  RampType rampType;   // 이전 포인트 → 이 포인트까지의 커브 형태

  ProfileWaypoint({
    required this.timeOffset,
    required this.targetValue,
    this.rampType = RampType.linear,
  });

  Map<String, dynamic> toJson() => {
        'timeOffset': timeOffset,
        'targetValue': targetValue,
        'rampType': rampType.index,
      };

  factory ProfileWaypoint.fromJson(Map<String, dynamic> json) {
    return ProfileWaypoint(
      timeOffset: (json['timeOffset'] as num).toDouble(),
      targetValue: (json['targetValue'] as num).toDouble(),
      rampType: RampType.values[json['rampType'] as int? ?? 0],
    );
  }

  ProfileWaypoint copyWith({
    double? timeOffset,
    double? targetValue,
    RampType? rampType,
  }) {
    return ProfileWaypoint(
      timeOffset: timeOffset ?? this.timeOffset,
      targetValue: targetValue ?? this.targetValue,
      rampType: rampType ?? this.rampType,
    );
  }
}

/// 에스프레소 레시피 데이터 모델
///
/// Pre-infusion + Transition + Extraction(변곡점 포함) 구성.
/// 프로파일 모드(압력/유량)는 전체 레시피에서 통일.
class EspressoRecipe {
  final String id;
  String name;
  ProfileMode profileMode;

  // Pre-infusion
  double preInfusionTime;       // 초 (0 = 생략)
  double preInfusionTarget;     // bar 또는 ml/s
  RampType preInfusionRampType; // 0→target 커브 형태

  // Transition (PI → Extraction)
  double transitionTime;        // 초

  // Extraction
  double extractionTarget;      // bar 또는 ml/s (초기 목표값)
  RampType extractionRampType;  // 전환 커브 형태

  /// Extraction 구간 변곡점 목록.
  /// timeOffset 기준 오름차순 정렬.
  /// 비어있으면 extractionTarget을 끝까지 유지.
  List<ProfileWaypoint> waypoints;

  // Temperature
  double temperature;           // ℃ (단일 고정)

  // End conditions
  double endWeight;             // g
  double maxShotTime;           // s (안전장치)

  DateTime createdAt;
  DateTime updatedAt;

  EspressoRecipe({
    required this.id,
    this.name = 'New Recipe',
    this.profileMode = ProfileMode.pressure,
    this.preInfusionTime = 5.0,
    this.preInfusionTarget = 3.0,
    this.preInfusionRampType = RampType.linear,
    this.transitionTime = 2.0,
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

  /// Extraction 구간 시작 시각 (절대 시간)
  double get extractionStartTime =>
      hasPreInfusion ? preInfusionTime + transitionTime : 0;

  /// Extraction 구간에 사용 가능한 시간 (변곡점 timeOffset 상한)
  double get extractionDuration =>
      maxShotTime - extractionStartTime;

  String get endConditionDescription =>
      '${endWeight}g 또는 ${maxShotTime}s (먼저 도달 시 종료)';

  /// waypoints를 timeOffset 기준으로 정렬
  void sortWaypoints() {
    waypoints.sort((a, b) => a.timeOffset.compareTo(b.timeOffset));
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'profileMode': profileMode.index,
        'preInfusionTime': preInfusionTime,
        'preInfusionTarget': preInfusionTarget,
        'preInfusionRampType': preInfusionRampType.index,
        'transitionTime': transitionTime,
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
    return EspressoRecipe(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'New Recipe',
      profileMode: ProfileMode.values[json['profileMode'] as int? ?? 0],
      preInfusionTime: (json['preInfusionTime'] as num?)?.toDouble() ?? 5.0,
      preInfusionTarget:
          (json['preInfusionTarget'] as num?)?.toDouble() ?? 3.0,
      preInfusionRampType:
          RampType.values[json['preInfusionRampType'] as int? ?? 0],
      transitionTime: (json['transitionTime'] as num?)?.toDouble() ?? 2.0,
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
    String? id,
    String? name,
    ProfileMode? profileMode,
    double? preInfusionTime,
    double? preInfusionTarget,
    RampType? preInfusionRampType,
    double? transitionTime,
    double? extractionTarget,
    RampType? extractionRampType,
    List<ProfileWaypoint>? waypoints,
    double? temperature,
    double? endWeight,
    double? maxShotTime,
  }) {
    return EspressoRecipe(
      id: id ?? this.id,
      name: name ?? this.name,
      profileMode: profileMode ?? this.profileMode,
      preInfusionTime: preInfusionTime ?? this.preInfusionTime,
      preInfusionTarget: preInfusionTarget ?? this.preInfusionTarget,
      preInfusionRampType: preInfusionRampType ?? this.preInfusionRampType,
      transitionTime: transitionTime ?? this.transitionTime,
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
