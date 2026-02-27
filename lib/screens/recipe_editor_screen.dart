import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/espresso_recipe.dart';
import '../services/recipe_service.dart';
import '../widgets/profile_graph.dart';

/// 에스프레소 레시피 편집 화면
///
/// 상단: 프로파일 그래프 (전체 너비, 고정)
/// 하단: Pre-infusion(Stage1) + Extraction(Stage2) + 변곡점(Stage3+) + 온도/종료
class RecipeEditorScreen extends StatefulWidget {
  final EspressoRecipe? existingRecipe;

  const RecipeEditorScreen({super.key, this.existingRecipe});

  @override
  State<RecipeEditorScreen> createState() => _RecipeEditorScreenState();
}

class _RecipeEditorScreenState extends State<RecipeEditorScreen> {
  late EspressoRecipe _recipe;
  late TextEditingController _nameController;

  static const Color extractionColor = Color(0xFFFFC107);

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
      body: Column(
        children: [
          // ── 상단 고정: 헤더 + 그래프 ──
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border:
                  Border(bottom: BorderSide(color: Color(0xFFE8E8F0))),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Column(
                children: [
                  _buildCompactHeader(),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 200,
                    child: _buildGraphPanel(),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 160,
                    child: _buildYieldGraphPanel(),
                  ),
                ],
              ),
            ),
          ),
          // ── 하단 스크롤: 컨트롤 ──
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(10),
                  child: _buildControlsGrid(constraints.maxWidth),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // 헤더
  // ─────────────────────────────────────────────

  Widget _buildCompactHeader() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 40,
            child: TextField(
              controller: _nameController,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Recipe Name',
                prefixIcon: const Icon(Icons.coffee, size: 18),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                isDense: true,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SegmentedButton<ProfileMode>(
          style: const ButtonStyle(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 8),
            ),
            textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12)),
          ),
          segments: const [
            ButtonSegment(
              value: ProfileMode.pressure,
              label: Text('bar'),
              icon: Icon(Icons.speed, size: 14),
            ),
            ButtonSegment(
              value: ProfileMode.flow,
              label: Text('ml/s'),
              icon: Icon(Icons.water_drop, size: 14),
            ),
          ],
          selected: {_recipe.profileMode},
          onSelectionChanged: (selected) {
            _updateRecipe((r) => r.copyWith(
                  profileMode: selected.first,
                  preInfusionTarget:
                      selected.first == ProfileMode.pressure ? 3.0 : 2.0,
                  extractionTarget:
                      selected.first == ProfileMode.pressure ? 9.0 : 4.0,
                ));
          },
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // 그래프
  // ─────────────────────────────────────────────

  Widget _buildGraphPanel() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8E8F0)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildLegendDot('PI', ProfileGraph.preInfusionColor),
              const SizedBox(width: 6),
              _buildLegendDot('Ext', ProfileGraph.extractionColor),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(child: ProfileGraph(recipe: _recipe)),
        ],
      ),
    );
  }

  Widget _buildYieldGraphPanel() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8E8F0)),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('Yield',
                  style: TextStyle(
                      fontSize: 10, color: Color(0xFF9E9E9E))),
            ],
          ),
          const SizedBox(height: 2),
          Expanded(child: YieldGraph(recipe: _recipe)),
        ],
      ),
    );
  }

  Widget _buildLegendDot(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration:
              BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 3),
        Text(label,
            style:
                const TextStyle(fontSize: 10, color: Color(0xFF9E9E9E))),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // 컨트롤 그리드
  // ─────────────────────────────────────────────

  Widget _buildControlsGrid(double availableWidth) {
    const double gap = 8;
    final wide = availableWidth >= 500;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // PI (Stage 1) + Extraction (Stage 2) 나란히
        if (wide)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildPreInfusionCard()),
                const SizedBox(width: gap),
                Expanded(child: _buildExtractionCard()),
              ],
            ),
          )
        else ...[
          _buildPreInfusionCard(),
          const SizedBox(height: gap),
          _buildExtractionCard(),
        ],
        const SizedBox(height: gap),

        // 변곡점 (Stage 3+)
        _buildWaypointsCard(),
        const SizedBox(height: gap),

        // 온도 + 종료조건
        if (wide)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildTemperatureCard()),
                const SizedBox(width: gap),
                Expanded(child: _buildEndConditionsCard()),
              ],
            ),
          )
        else ...[
          _buildTemperatureCard(),
          const SizedBox(height: gap),
          _buildEndConditionsCard(),
        ],
        const SizedBox(height: gap),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // Pre-infusion (Stage 1)
  // ─────────────────────────────────────────────

  Widget _buildPreInfusionCard() {
    final String unit = _recipe.unitLabel;
    final double maxTarget = _recipe.yAxisMax;
    final bool piOn = _recipe.hasPreInfusion;

    return _CompactCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _sectionHeader(
            'Pre-infusion',
            ProfileGraph.preInfusionColor,
            subtitle: piOn
                ? 'Stage 1 · ${_recipe.preInfusionTime.toStringAsFixed(1)}s'
                : 'Stage 1 · OFF',
          ),
          const SizedBox(height: 8),
          _compactSlider(
            label: '시간',
            value: _recipe.preInfusionTime,
            min: 0,
            max: 30,
            unit: 's',
            onChanged: (v) => _updateRecipe(
                (r) => r.copyWith(preInfusionTime: v)),
          ),
          _compactSlider(
            label: '타깃',
            value: _recipe.preInfusionTarget,
            min: 0,
            max: maxTarget,
            unit: unit,
            enabled: piOn,
            onChanged: (v) => _updateRecipe(
                (r) => r.copyWith(preInfusionTarget: v)),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Extraction (Stage 2) — 시간 없음
  // ─────────────────────────────────────────────

  Widget _buildExtractionCard() {
    final String unit = _recipe.unitLabel;
    final double maxTarget = _recipe.yAxisMax;

    return _CompactCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _sectionHeader(
              'Extraction', ProfileGraph.extractionColor,
              subtitle: 'Stage 2 · ${_recipe.extractionTime.toStringAsFixed(1)}s'),
          const SizedBox(height: 8),
          _compactSlider(
            label: '시간',
            value: _recipe.extractionTime,
            min: 1,
            max: 30,
            unit: 's',
            onChanged: (v) => _updateRecipe(
                (r) => r.copyWith(extractionTime: v)),
          ),
          _compactSlider(
            label: '타깃',
            value: _recipe.extractionTarget,
            min: 0,
            max: maxTarget,
            unit: unit,
            onChanged: (v) =>
                _updateRecipe((r) => r.copyWith(extractionTarget: v)),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // 변곡점 (Stage 3+)
  // ─────────────────────────────────────────────

  Widget _buildWaypointsCard() {
    final String unit = _recipe.unitLabel;
    final double maxTarget = _recipe.yAxisMax;

    return _CompactCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.timeline, size: 14, color: extractionColor),
              const SizedBox(width: 6),
              const Text('변곡점',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A2E),
                  )),
              const Spacer(),
              if (_recipe.waypoints.isEmpty)
                Text(
                  '${_recipe.extractionTarget.toStringAsFixed(1)} $unit 유지',
                  style: const TextStyle(
                      fontSize: 10, color: Color(0xFF9E9E9E)),
                ),
              IconButton(
                icon:
                    const Icon(Icons.add_circle_outline, size: 18),
                color: const Color(0xFF7C5CFC),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                    minWidth: 28, minHeight: 28),
                tooltip: 'Stage 추가',
                onPressed: _recipe.canAddWaypoint
                    ? () {
                        setState(() {
                          final lastValue =
                              _recipe.waypoints.isEmpty
                                  ? _recipe.extractionTarget
                                  : _recipe
                                      .waypoints.last.targetValue;
                          _recipe.waypoints.add(ProfileWaypoint(
                            duration: 5.0,
                            targetValue: lastValue,
                          ));
                        });
                      }
                    : null,
              ),
            ],
          ),
          for (int i = 0; i < _recipe.waypoints.length; i++)
            _buildWaypointRow(i, unit, maxTarget),
        ],
      ),
    );
  }

  Widget _buildWaypointRow(
    int index,
    String unit,
    double maxTarget,
  ) {
    final wp = _recipe.waypoints[index];
    final stageNum = index + 3; // Stage 3, 4, 5...

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: extractionColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: extractionColor.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: extractionColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text('S$stageNum',
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                ),
                const SizedBox(width: 6),
                Text(
                  '${wp.duration.toStringAsFixed(1)}s → ${wp.targetValue.toStringAsFixed(1)} $unit',
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF616161)),
                ),
                const Spacer(),
                InkWell(
                  onTap: () {
                    setState(() {
                      _recipe.waypoints.removeAt(index);
                    });
                  },
                  child: const Icon(Icons.close,
                      size: 16, color: Colors.red),
                ),
              ],
            ),
            const SizedBox(height: 4),
            _compactSlider(
              label: '시간',
              value: wp.duration,
              min: 1,
              max: 30,
              unit: 's',
              onChanged: (v) {
                setState(() {
                  _recipe.waypoints[index] =
                      wp.copyWith(duration: v);
                });
              },
            ),
            _compactSlider(
              label: '목표',
              value: wp.targetValue.clamp(0, maxTarget),
              min: 0,
              max: maxTarget,
              unit: unit,
              onChanged: (v) {
                setState(() {
                  _recipe.waypoints[index] =
                      wp.copyWith(targetValue: v);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // 온도 / 종료조건
  // ─────────────────────────────────────────────

  Widget _buildTemperatureCard() {
    return _CompactCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            children: [
              Icon(Icons.thermostat, size: 14, color: Color(0xFFFF5722)),
              SizedBox(width: 6),
              Text('온도',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A2E),
                  )),
            ],
          ),
          const SizedBox(height: 8),
          _compactSlider(
            label: '',
            value: _recipe.temperature,
            min: 80,
            max: 100,
            unit: '℃',
            divisions: 40,
            onChanged: (v) =>
                _updateRecipe((r) => r.copyWith(temperature: v)),
          ),
        ],
      ),
    );
  }

  Widget _buildEndConditionsCard() {
    return _CompactCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            children: [
              Icon(Icons.flag, size: 14, color: Colors.blueGrey),
              SizedBox(width: 6),
              Text('종료',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A2E),
                  )),
            ],
          ),
          const SizedBox(height: 8),
          _compactSlider(
            label: 'g',
            value: _recipe.endWeight,
            min: 0,
            max: 100,
            unit: 'g',
            onChanged: (v) =>
                _updateRecipe((r) => r.copyWith(endWeight: v)),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // 공통 위젯
  // ─────────────────────────────────────────────

  Widget _sectionHeader(String title, Color color,
      {String? subtitle, Widget? trailing}) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration:
              BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A2E),
            )),
        if (subtitle != null) ...[
          const SizedBox(width: 4),
          Text('($subtitle)',
              style: const TextStyle(
                  fontSize: 10, color: Color(0xFF9E9E9E))),
        ],
        if (trailing != null) ...[const Spacer(), trailing],
      ],
    );
  }

  Widget _compactSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required String unit,
    required ValueChanged<double> onChanged,
    int? divisions,
    bool enabled = true,
  }) {
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          if (label.isNotEmpty)
            SizedBox(
              width: 28,
              child: Text(label,
                  style: TextStyle(
                    fontSize: 10,
                    color: enabled
                        ? const Color(0xFF616161)
                        : Colors.grey,
                  )),
            ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 12),
                activeTrackColor: enabled
                    ? const Color(0xFF7C5CFC)
                    : Colors.grey[300],
                inactiveTrackColor: Colors.grey[200],
                thumbColor: enabled
                    ? const Color(0xFF7C5CFC)
                    : Colors.grey[400],
              ),
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                divisions: divisions ??
                    ((max - min) * 2).toInt().clamp(1, 200),
                onChanged: enabled ? onChanged : null,
              ),
            ),
          ),
          Text(
            '${value.toStringAsFixed(1)}$unit',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: enabled ? const Color(0xFF1A1A2E) : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

}

/// 압축형 섹션 카드
class _CompactCard extends StatelessWidget {
  final Widget child;

  const _CompactCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8E8F0)),
      ),
      child: child,
    );
  }
}
