import 'dart:convert';

/// 프로파일 모드: 전체 레시피에서 압력 또는 유량 중 하나로 통일
enum ProfileMode { pressure, flow }

/// 램프 타입: 목표값까지 도달하는 커브 형태
/// - linear: 일정한 속도로 직선 상승
/// - exponential: 초반 빠르게 상승 후 점진적으로 수렴 (1 - e^(-kt))
enum RampType { linear, exponential }

/// 에스프레소 레시피 데이터 모델
///
/// Pre-infusion + Transition + Extraction 세 구간으로 구성.
/// 프로파일 모드(압력/유량)는 전체 레시피에서 통일.
class EspressoRecipe {
  final String id;
  String name;
  ProfileMode profileMode;

  // Pre-infusion
  double preInfusionTime;       // 초 (0 = pre-infusion 생략)
  double preInfusionTarget;     // bar 또는 ml/s
  RampType preInfusionRampType; // 0→target 커브 형태

  // Transition (PI → Extraction)
  double transitionTime;        // 초 — PI target에서 Extraction target까지 램프 시간

  // Extraction
  double extractionTarget;      // bar 또는 ml/s
  RampType extractionRampType;  // PI target→Extraction target 전환 커브 형태

  // Temperature
  double temperature;           // ℃ (단일 고정)

  // End conditions
  double endWeight;             // g (종료 무게)
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
    this.temperature = 93.0,
    this.endWeight = 36.0,
    this.maxShotTime = 40.0,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// 프로파일 모드에 따른 Y축 단위 문자열
  String get unitLabel =>
      profileMode == ProfileMode.pressure ? 'bar' : 'ml/s';

  /// 프로파일 모드에 따른 Y축 최대값
  double get yAxisMax =>
      profileMode == ProfileMode.pressure ? 15.0 : 10.0;

  /// Pre-infusion 사용 여부
  bool get hasPreInfusion => preInfusionTime > 0;

  /// Extraction 시작 시점 (PI 시간 + 전환 시간)
  double get extractionStartTime =>
      hasPreInfusion ? preInfusionTime + transitionTime : 0;

  /// 종료 조건 설명
  String get endConditionDescription =>
      '${endWeight}g 또는 ${maxShotTime}s (먼저 도달 시 종료)';

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
      temperature: temperature ?? this.temperature,
      endWeight: endWeight ?? this.endWeight,
      maxShotTime: maxShotTime ?? this.maxShotTime,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
