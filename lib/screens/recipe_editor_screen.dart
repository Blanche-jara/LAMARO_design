import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/espresso_recipe.dart';
import '../services/recipe_service.dart';
import '../widgets/profile_graph.dart';

/// 에스프레소 레시피 편집 화면
///
/// 모든 제어 요소 입력 + 실시간 프로파일 그래프 프리뷰.
/// 입력값 변경 시 그래프가 즉시 업데이트됨.
class RecipeEditorScreen extends StatefulWidget {
  /// null이면 새 레시피 생성, 값이 있으면 기존 레시피 수정
  final EspressoRecipe? existingRecipe;

  const RecipeEditorScreen({super.key, this.existingRecipe});

  @override
  State<RecipeEditorScreen> createState() => _RecipeEditorScreenState();
}

class _RecipeEditorScreenState extends State<RecipeEditorScreen> {
  late EspressoRecipe _recipe;
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _recipe = widget.existingRecipe?.copyWith() ??
        EspressoRecipe(
          id: context.read<RecipeService>().generateId(),
        );
    _nameController = TextEditingController(text: _recipe.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _updateRecipe(EspressoRecipe Function(EspressoRecipe) updater) {
    setState(() {
      _recipe = updater(_recipe);
    });
  }

  Future<void> _saveRecipe() async {
    _recipe.name = _nameController.text.trim().isEmpty
        ? 'New Recipe'
        : _nameController.text.trim();
    _recipe.updatedAt = DateTime.now();

    final service = context.read<RecipeService>();
    if (widget.existingRecipe != null) {
      await service.updateRecipe(_recipe);
    } else {
      await service.addRecipe(_recipe);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('레시피가 저장되었습니다'),
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5FA),
      appBar: AppBar(
        title: const Text('레시피 편집'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: _saveRecipe,
            icon: const Icon(Icons.save, size: 20),
            label: const Text('저장'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 레시피 이름
            _buildNameInput(),
            const SizedBox(height: 16),

            // 프로파일 모드 토글
            _buildModeToggle(),
            const SizedBox(height: 16),

            // 프로파일 그래프 프리뷰
            _buildGraphPreview(),
            const SizedBox(height: 20),

            // Pre-infusion 섹션
            _buildPreInfusionSection(),
            const SizedBox(height: 16),

            // Extraction 섹션
            _buildExtractionSection(),
            const SizedBox(height: 16),

            // 변곡점 (Waypoints) 섹션
            _buildWaypointsSection(),
            const SizedBox(height: 16),

            // 온도 섹션
            _buildTemperatureSection(),
            const SizedBox(height: 16),

            // 종료 조건 섹션
            _buildEndConditionsSection(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  /// 레시피 이름 입력
  Widget _buildNameInput() {
    return _SectionCard(
      child: TextField(
        controller: _nameController,
        decoration: const InputDecoration(
          labelText: '레시피 이름',
          hintText: 'New Recipe',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.coffee),
        ),
      ),
    );
  }

  /// 프로파일 모드 토글 (압력 / 유량)
  Widget _buildModeToggle() {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '프로파일 모드',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<ProfileMode>(
            segments: const [
              ButtonSegment(
                value: ProfileMode.pressure,
                label: Text('압력 (bar)'),
                icon: Icon(Icons.speed),
              ),
              ButtonSegment(
                value: ProfileMode.flow,
                label: Text('유량 (ml/s)'),
                icon: Icon(Icons.water_drop),
              ),
            ],
            selected: {_recipe.profileMode},
            onSelectionChanged: (selected) {
              _updateRecipe((r) => r.copyWith(
                    profileMode: selected.first,
                    // 모드 변경 시 기본값으로 리셋
                    preInfusionTarget:
                        selected.first == ProfileMode.pressure ? 3.0 : 2.0,
                    extractionTarget:
                        selected.first == ProfileMode.pressure ? 9.0 : 4.0,
                  ));
            },
          ),
        ],
      ),
    );
  }

  /// 프로파일 그래프 프리뷰
  Widget _buildGraphPreview() {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '프로파일 프리뷰',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const Spacer(),
              // 범례
              _buildLegendItem('Pre-infusion', ProfileGraph.preInfusionColor),
              const SizedBox(width: 8),
              _buildLegendItem('Transition', ProfileGraph.transitionColor),
              const SizedBox(width: 8),
              _buildLegendItem('Extraction', ProfileGraph.extractionColor),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: ProfileGraph(recipe: _recipe),
          ),
        ],
      ),
    );
  }

  /// 범례 아이템
  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.3),
            border: Border.all(color: color, width: 1.5),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF616161)),
        ),
      ],
    );
  }

  /// Pre-infusion 설정 섹션
  Widget _buildPreInfusionSection() {
    final String unit = _recipe.unitLabel;
    final double maxTarget = _recipe.yAxisMax;

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: ProfileGraph.preInfusionColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Pre-infusion',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const Spacer(),
              if (!_recipe.hasPreInfusion)
                const Text(
                  '비활성 (시간 = 0)',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // 시간 슬라이더
          _buildSliderRow(
            label: '시간',
            value: _recipe.preInfusionTime,
            min: 0,
            max: 30,
            unit: 's',
            onChanged: (v) =>
                _updateRecipe((r) => r.copyWith(preInfusionTime: v)),
          ),
          const SizedBox(height: 8),

          // 타깃 압력/유량 슬라이더
          _buildSliderRow(
            label: '타깃 $unit',
            value: _recipe.preInfusionTarget,
            min: 0,
            max: maxTarget,
            unit: unit,
            enabled: _recipe.hasPreInfusion,
            onChanged: (v) =>
                _updateRecipe((r) => r.copyWith(preInfusionTarget: v)),
          ),

          // 램프 타입 토글
          if (_recipe.hasPreInfusion) ...[
            const SizedBox(height: 8),
            _buildRampTypeToggle(
              label: '램프 커브',
              value: _recipe.preInfusionRampType,
              onChanged: (v) =>
                  _updateRecipe((r) => r.copyWith(preInfusionRampType: v)),
            ),
          ],

          // 시간 우선 규칙 안내
          if (_recipe.hasPreInfusion)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha:0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.blue.withValues(alpha:0.2),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '시간 우선: 설정 시간이 지나면 타깃 도달 여부와 관계없이 Extraction으로 자동 전환됩니다.',
                        style: TextStyle(fontSize: 11, color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Extraction 설정 섹션
  Widget _buildExtractionSection() {
    final String unit = _recipe.unitLabel;
    final double maxTarget = _recipe.yAxisMax;

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: ProfileGraph.extractionColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Extraction',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 전환 시간 슬라이더 (PI → Extraction 램프)
          if (_recipe.hasPreInfusion) ...[
            _buildSliderRow(
              label: '전환 시간',
              value: _recipe.transitionTime,
              min: 0.5,
              max: 10,
              unit: 's',
              onChanged: (v) =>
                  _updateRecipe((r) => r.copyWith(transitionTime: v)),
            ),
            const SizedBox(height: 8),
          ],

          // 타깃 압력/유량 슬라이더
          _buildSliderRow(
            label: '타깃 $unit',
            value: _recipe.extractionTarget,
            min: 0,
            max: maxTarget,
            unit: unit,
            onChanged: (v) =>
                _updateRecipe((r) => r.copyWith(extractionTarget: v)),
          ),
          const SizedBox(height: 8),

          // 램프 타입 토글 (전환 커브 형태)
          _buildRampTypeToggle(
            label: '전환 커브',
            value: _recipe.extractionRampType,
            onChanged: (v) =>
                _updateRecipe((r) => r.copyWith(extractionRampType: v)),
          ),
        ],
      ),
    );
  }

  /// 변곡점 (Waypoints) 섹션
  ///
  /// Extraction 구간 내에서 시간별 목표값을 변경하는 변곡점을 추가/삭제.
  Widget _buildWaypointsSection() {
    final String unit = _recipe.unitLabel;
    final double maxTarget = _recipe.yAxisMax;
    final double maxOffset = _recipe.extractionDuration;

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timeline, size: 16, color: extractionColor),
              const SizedBox(width: 8),
              const Text(
                'Extraction 변곡점',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const Spacer(),
              // 추가 버튼
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 22),
                color: const Color(0xFF7C5CFC),
                tooltip: '변곡점 추가',
                onPressed: maxOffset > 0
                    ? () {
                        setState(() {
                          // 마지막 포인트 이후 적절한 위치에 추가
                          final lastOffset = _recipe.waypoints.isEmpty
                              ? 0.0
                              : _recipe.waypoints.last.timeOffset;
                          final newOffset =
                              (lastOffset + 5.0).clamp(0.0, maxOffset);
                          final lastValue = _recipe.waypoints.isEmpty
                              ? _recipe.extractionTarget
                              : _recipe.waypoints.last.targetValue;
                          _recipe.waypoints.add(ProfileWaypoint(
                            timeOffset: newOffset,
                            targetValue: lastValue,
                          ));
                          _recipe.sortWaypoints();
                        });
                      }
                    : null,
              ),
            ],
          ),

          if (_recipe.waypoints.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Extraction 구간 동안 ${_recipe.extractionTarget.toStringAsFixed(1)} $unit 유지. '
                '+ 버튼으로 변곡점을 추가하세요.',
                style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
              ),
            ),

          // 변곡점 목록
          for (int i = 0; i < _recipe.waypoints.length; i++)
            _buildWaypointRow(i, unit, maxTarget, maxOffset),
        ],
      ),
    );
  }

  /// 개별 변곡점 행
  Widget _buildWaypointRow(
    int index,
    String unit,
    double maxTarget,
    double maxOffset,
  ) {
    final wp = _recipe.waypoints[index];

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: extractionColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: extractionColor.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            // 헤더: #번호 + 삭제 버튼
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: extractionColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '#${index + 1}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${wp.timeOffset.toStringAsFixed(1)}s → ${wp.targetValue.toStringAsFixed(1)} $unit',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF616161),
                  ),
                ),
                const Spacer(),
                // 커브 타입 미니 토글
                SegmentedButton<RampType>(
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    padding: WidgetStatePropertyAll(
                      const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    textStyle: WidgetStatePropertyAll(
                      const TextStyle(fontSize: 10),
                    ),
                  ),
                  segments: const [
                    ButtonSegment(
                      value: RampType.linear,
                      label: Text('Lin'),
                    ),
                    ButtonSegment(
                      value: RampType.exponential,
                      label: Text('Exp'),
                    ),
                  ],
                  selected: {wp.rampType},
                  onSelectionChanged: (s) {
                    setState(() {
                      _recipe.waypoints[index] =
                          wp.copyWith(rampType: s.first);
                    });
                  },
                ),
                const SizedBox(width: 4),
                // 삭제 버튼
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                  color: Colors.red,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  tooltip: '삭제',
                  onPressed: () {
                    setState(() {
                      _recipe.waypoints.removeAt(index);
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 6),
            // 시간 슬라이더
            _buildSliderRow(
              label: '시간',
              value: wp.timeOffset.clamp(0, maxOffset),
              min: 0,
              max: maxOffset > 0 ? maxOffset : 1,
              unit: 's',
              onChanged: (v) {
                setState(() {
                  _recipe.waypoints[index] = wp.copyWith(timeOffset: v);
                  _recipe.sortWaypoints();
                });
              },
            ),
            // 목표값 슬라이더
            _buildSliderRow(
              label: '목표 $unit',
              value: wp.targetValue.clamp(0, maxTarget),
              min: 0,
              max: maxTarget,
              unit: unit,
              onChanged: (v) {
                setState(() {
                  _recipe.waypoints[index] = wp.copyWith(targetValue: v);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  static const Color extractionColor = Color(0xFFFFC107);

  /// 온도 설정 섹션
  Widget _buildTemperatureSection() {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.thermostat, size: 16, color: Color(0xFFFF5722)),
              SizedBox(width: 8),
              Text(
                '추출 온도',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSliderRow(
            label: '온도',
            value: _recipe.temperature,
            min: 80,
            max: 100,
            unit: '℃',
            divisions: 40, // 0.5도 단위
            onChanged: (v) =>
                _updateRecipe((r) => r.copyWith(temperature: v)),
          ),
        ],
      ),
    );
  }

  /// 종료 조건 설정 섹션
  Widget _buildEndConditionsSection() {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.flag, size: 16, color: Colors.blueGrey),
              SizedBox(width: 8),
              Text(
                '종료 조건',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            '먼저 도달하는 조건으로 샷이 종료됩니다.',
            style: TextStyle(fontSize: 11, color: Color(0xFF616161)),
          ),
          const SizedBox(height: 12),

          // 종료 무게
          _buildSliderRow(
            label: '종료 무게',
            value: _recipe.endWeight,
            min: 0,
            max: 100,
            unit: 'g',
            onChanged: (v) =>
                _updateRecipe((r) => r.copyWith(endWeight: v)),
          ),
          const SizedBox(height: 8),

          // 최대 시간 (안전장치)
          _buildSliderRow(
            label: '최대 시간',
            value: _recipe.maxShotTime,
            min: 10,
            max: 120,
            unit: 's',
            onChanged: (v) =>
                _updateRecipe((r) => r.copyWith(maxShotTime: v)),
          ),

          // 안전장치 안내
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha:0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.orange.withValues(alpha:0.2),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber, size: 16, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '최대 시간은 안전장치입니다. 도달 시 설정 오류 가능성을 경고합니다.',
                      style: TextStyle(fontSize: 11, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 램프 타입 토글 (Linear / Exponential)
  Widget _buildRampTypeToggle({
    required String label,
    required RampType value,
    required ValueChanged<RampType> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A2E)),
          ),
        ),
        Expanded(
          child: SegmentedButton<RampType>(
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              textStyle: WidgetStatePropertyAll(
                const TextStyle(fontSize: 12),
              ),
            ),
            segments: const [
              ButtonSegment(
                value: RampType.linear,
                label: Text('Linear'),
                icon: Icon(Icons.trending_up, size: 16),
              ),
              ButtonSegment(
                value: RampType.exponential,
                label: Text('Expo'),
                icon: Icon(Icons.ssid_chart, size: 16),
              ),
            ],
            selected: {value},
            onSelectionChanged: (s) => onChanged(s.first),
          ),
        ),
      ],
    );
  }

  /// 슬라이더 + 숫자 표시 행
  Widget _buildSliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required String unit,
    required ValueChanged<double> onChanged,
    int? divisions,
    bool enabled = true,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: enabled ? const Color(0xFF1A1A2E) : Colors.grey,
            ),
          ),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions ?? ((max - min) * 2).toInt().clamp(1, 200),
            onChanged: enabled ? onChanged : null,
            activeColor: enabled ? const Color(0xFF7C5CFC) : Colors.grey,
          ),
        ),
        SizedBox(
          width: 72,
          child: Text(
            '${value.toStringAsFixed(1)} $unit',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: enabled ? const Color(0xFF1A1A2E) : Colors.grey,
            ),
          ),
        ),
      ],
    );
  }
}

/// 섹션 카드 래퍼 위젯
class _SectionCard extends StatelessWidget {
  final Widget child;

  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8F0)),
      ),
      child: child,
    );
  }
}
