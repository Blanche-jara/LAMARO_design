import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/espresso_recipe.dart';
import 'profile_graph.dart';

/// 인터랙티브 프로파일 그래프
///
/// ProfileGraph를 감싸서 터치 인터랙션을 추가한다.
/// - 라인 위 탭 → 노드 추가 (시간순 삽입, 기존 노드 시프트)
/// - 노드 드래그 → 파라미터 실시간 변경
class InteractiveProfileGraph extends StatefulWidget {
  final EspressoRecipe recipe;
  final ValueChanged<EspressoRecipe> onRecipeChanged;

  const InteractiveProfileGraph({
    super.key,
    required this.recipe,
    required this.onRecipeChanged,
  });

  @override
  State<InteractiveProfileGraph> createState() =>
      _InteractiveProfileGraphState();
}

/// 통합 노드 정보
class _NodeInfo {
  final double time;
  final double value;
  final String role; // 'origin', 'pi', 'ext', 'wp0', 'wp1', ...

  const _NodeInfo(this.time, this.value, this.role);
}

class _InteractiveProfileGraphState extends State<InteractiveProfileGraph> {
  int? _draggingNodeIndex;
  int? _selectedNodeIndex;

  static const double _hitRadiusPx = 24.0;
  static const double _minGap = 0.1; // 노드 간 최소 시간 간격 (s)

  // ─────────────────────────────────────────────
  // 통합 노드 리스트
  // ─────────────────────────────────────────────

  List<_NodeInfo> _buildNodeList() {
    final r = widget.recipe;
    final nodes = <_NodeInfo>[const _NodeInfo(0, 0, 'origin')];
    if (r.hasPreInfusion) {
      nodes.add(_NodeInfo(r.preInfusionTime, r.preInfusionTarget, 'pi'));
    }
    nodes.add(_NodeInfo(r.extractionTime, r.extractionTarget, 'ext'));
    for (int i = 0; i < r.waypoints.length; i++) {
      nodes.add(
          _NodeInfo(r.waypoints[i].time, r.waypoints[i].targetValue, 'wp$i'));
    }
    return nodes;
  }

  // ─────────────────────────────────────────────
  // 픽셀 ↔ 차트 좌표 변환
  // ─────────────────────────────────────────────

  Offset _pixelToChart(Offset pixel, Size widgetSize) {
    final chartLeft = ProfileGraph.chartLeftReserved;
    final chartTop = ProfileGraph.chartTopPadding;
    final chartRight = widgetSize.width - ProfileGraph.chartRightPadding;
    final chartBottom =
        widgetSize.height - ProfileGraph.chartBottomReserved;

    final chartWidth = chartRight - chartLeft;
    final chartHeight = chartBottom - chartTop;
    if (chartWidth <= 0 || chartHeight <= 0) return Offset.zero;

    final maxX = widget.recipe.maxShotTime;
    final maxY = widget.recipe.yAxisMax;

    final time = ((pixel.dx - chartLeft) / chartWidth) * maxX;
    final value = ((chartBottom - pixel.dy) / chartHeight) * maxY;

    return Offset(
      time.clamp(0, maxX),
      value.clamp(0, maxY),
    );
  }

  Offset _chartToPixel(double time, double value, Size widgetSize) {
    final chartLeft = ProfileGraph.chartLeftReserved;
    final chartTop = ProfileGraph.chartTopPadding;
    final chartRight = widgetSize.width - ProfileGraph.chartRightPadding;
    final chartBottom =
        widgetSize.height - ProfileGraph.chartBottomReserved;

    final chartWidth = chartRight - chartLeft;
    final chartHeight = chartBottom - chartTop;

    final maxX = widget.recipe.maxShotTime;
    final maxY = widget.recipe.yAxisMax;

    final px = chartLeft + (time / maxX) * chartWidth;
    final py = chartBottom - (value / maxY) * chartHeight;

    return Offset(px, py);
  }

  // ─────────────────────────────────────────────
  // 노드 히트 테스트
  // ─────────────────────────────────────────────

  /// 터치 위치에서 가장 가까운 노드 인덱스 반환 (origin 제외)
  int? _findNearestNode(Offset touchPixel, Size widgetSize) {
    final nodes = _buildNodeList();
    double minDist = double.infinity;
    int? closest;

    for (int i = 1; i < nodes.length; i++) {
      // origin(0) 제외
      final nodePixel =
          _chartToPixel(nodes[i].time, nodes[i].value, widgetSize);
      final dist = (touchPixel - nodePixel).distance;
      if (dist < minDist && dist < _hitRadiusPx) {
        minDist = dist;
        closest = i;
      }
    }
    return closest;
  }

  /// 터치 위치가 프로파일 라인 근처인지 확인
  bool _isTouchOnLine(Offset touchPixel, Size widgetSize) {
    final chartCoord = _pixelToChart(touchPixel, widgetSize);
    final time = chartCoord.dx;

    // 차트 범위 밖이면 무시
    if (time <= 0 || time >= widget.recipe.maxShotTime) return false;

    final profileValue =
        ProfileGraph.profileValueAt(widget.recipe, time);
    final linePx =
        _chartToPixel(time, profileValue, widgetSize);

    // Y 방향 거리만 확인 (X는 이미 time으로 매칭)
    return (touchPixel.dy - linePx.dy).abs() < _hitRadiusPx;
  }

  // ─────────────────────────────────────────────
  // 제스처 핸들러
  // ─────────────────────────────────────────────

  void _handleTap(Offset localPosition, Size widgetSize) {
    // 1. 기존 노드 근처 탭 → 선택만
    final nodeIdx = _findNearestNode(localPosition, widgetSize);
    if (nodeIdx != null) {
      setState(() => _selectedNodeIndex = nodeIdx);
      return;
    }

    // 2. 라인 위 탭 → 노드 추가
    if (!_isTouchOnLine(localPosition, widgetSize)) {
      setState(() => _selectedNodeIndex = null);
      return;
    }

    final chartCoord = _pixelToChart(localPosition, widgetSize);
    final tapTime = chartCoord.dx;
    final tapValue =
        ProfileGraph.profileValueAt(widget.recipe, tapTime);

    _insertNodeAtTime(tapTime, tapValue);
    HapticFeedback.lightImpact();
  }

  void _handleDragStart(Offset localPosition, Size widgetSize) {
    final nodeIdx = _findNearestNode(localPosition, widgetSize);
    if (nodeIdx == null) return;

    setState(() {
      _draggingNodeIndex = nodeIdx;
      _selectedNodeIndex = nodeIdx;
    });
    HapticFeedback.selectionClick();
  }

  void _handleDragUpdate(Offset localPosition, Size widgetSize) {
    if (_draggingNodeIndex == null) return;

    final chartCoord = _pixelToChart(localPosition, widgetSize);
    final nodes = _buildNodeList();
    final idx = _draggingNodeIndex!;
    if (idx >= nodes.length) return;

    // 인접 노드 사이로 시간 클램핑
    final prevTime = (idx > 0) ? nodes[idx - 1].time : 0.0;
    final nextTime = (idx < nodes.length - 1)
        ? nodes[idx + 1].time
        : widget.recipe.maxShotTime;

    final clampedTime =
        chartCoord.dx.clamp(prevTime + _minGap, nextTime - _minGap);
    final clampedValue =
        chartCoord.dy.clamp(0.0, widget.recipe.yAxisMax);

    _applyDragToRecipe(idx, clampedTime, clampedValue);
  }

  void _handleDragEnd() {
    setState(() {
      _draggingNodeIndex = null;
    });
  }

  // ─────────────────────────────────────────────
  // 노드 삽입 (탭 → 추가)
  // ─────────────────────────────────────────────

  void _insertNodeAtTime(double time, double value) {
    final r = widget.recipe;
    final piTime = r.preInfusionTime;
    final extTime = r.extractionTime;

    EspressoRecipe newRecipe;

    if (!r.hasPreInfusion && time < extTime) {
      // Case A: PI 꺼짐, Ext 앞에 탭 → PI 활성화
      newRecipe = r.copyWith(
        preInfusionTime: time,
        preInfusionTarget: value,
        preInfusionRampType: RampType.linear,
      );
    } else if (r.hasPreInfusion && time < piTime) {
      // Case B: PI 앞에 탭 → 새→PI, 기존PI→Ext, 기존Ext→WP[0]
      if (r.waypoints.length >= 7) return; // 시프트로 WP 1개 추가됨
      final newWaypoints = [
        ProfileWaypoint(
          time: extTime,
          targetValue: r.extractionTarget,
          rampType: r.extractionRampType,
        ),
        ...r.waypoints.map((w) => w.copyWith()),
      ];
      newRecipe = r.copyWith(
        preInfusionTime: time,
        preInfusionTarget: value,
        preInfusionRampType: RampType.linear,
        extractionTime: piTime,
        extractionTarget: r.preInfusionTarget,
        extractionRampType: r.preInfusionRampType,
        waypoints: newWaypoints,
      );
    } else if (time >= piTime && time < extTime) {
      // Case C: PI~Ext 사이 탭 → 새→Ext, 기존Ext→WP[0]
      if (r.waypoints.length >= 7) return;
      final newWaypoints = [
        ProfileWaypoint(
          time: extTime,
          targetValue: r.extractionTarget,
          rampType: r.extractionRampType,
        ),
        ...r.waypoints.map((w) => w.copyWith()),
      ];
      newRecipe = r.copyWith(
        extractionTime: time,
        extractionTarget: value,
        extractionRampType: RampType.linear,
        waypoints: newWaypoints,
      );
    } else {
      // Case D: Ext 이후 탭 → waypoints에 시간순 삽입
      if (!r.canAddWaypoint) return;
      final newWp = ProfileWaypoint(
        time: time,
        targetValue: value,
        rampType: RampType.linear,
      );
      final newWaypoints = [
        ...r.waypoints.map((w) => w.copyWith()),
        newWp,
      ];
      newWaypoints.sort((a, b) => a.time.compareTo(b.time));
      newRecipe = r.copyWith(waypoints: newWaypoints);
    }

    widget.onRecipeChanged(newRecipe);
  }

  // ─────────────────────────────────────────────
  // 드래그 적용
  // ─────────────────────────────────────────────

  void _applyDragToRecipe(int unifiedIndex, double time, double value) {
    final r = widget.recipe;
    final hasPI = r.hasPreInfusion;

    EspressoRecipe newRecipe;

    if (hasPI && unifiedIndex == 1) {
      // PI 노드 드래그
      newRecipe = r.copyWith(
        preInfusionTime: time,
        preInfusionTarget: value,
      );
    } else if ((hasPI && unifiedIndex == 2) ||
        (!hasPI && unifiedIndex == 1)) {
      // Extraction 노드 드래그
      newRecipe = r.copyWith(
        extractionTime: time,
        extractionTarget: value,
      );
    } else {
      // Waypoint 드래그
      final wpIndex = hasPI ? unifiedIndex - 3 : unifiedIndex - 2;
      if (wpIndex < 0 || wpIndex >= r.waypoints.length) return;
      final newWaypoints = r.waypoints.map((w) => w.copyWith()).toList();
      newWaypoints[wpIndex] = newWaypoints[wpIndex].copyWith(
        time: time,
        targetValue: value,
      );
      newRecipe = r.copyWith(waypoints: newWaypoints);
    }

    widget.onRecipeChanged(newRecipe);
  }

  // ─────────────────────────────────────────────
  // 시각적 피드백
  // ─────────────────────────────────────────────

  Widget _buildHighlightOverlay(Size widgetSize) {
    final idx = _draggingNodeIndex ?? _selectedNodeIndex;
    if (idx == null) return const SizedBox.shrink();

    final nodes = _buildNodeList();
    if (idx >= nodes.length) return const SizedBox.shrink();

    final node = nodes[idx];
    final pixel = _chartToPixel(node.time, node.value, widgetSize);

    return Positioned(
      left: pixel.dx - 14,
      top: pixel.dy - 14,
      child: IgnorePointer(
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF7C5CFC),
              width: 2.5,
            ),
            color: const Color(0xFF7C5CFC).withValues(alpha: 0.15),
          ),
        ),
      ),
    );
  }

  Widget _buildDragTooltip(Size widgetSize) {
    if (_draggingNodeIndex == null) return const SizedBox.shrink();

    final nodes = _buildNodeList();
    if (_draggingNodeIndex! >= nodes.length) return const SizedBox.shrink();

    final node = nodes[_draggingNodeIndex!];
    final pixel = _chartToPixel(node.time, node.value, widgetSize);

    return Positioned(
      left: pixel.dx - 36,
      top: pixel.dy - 34,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '${node.time.toStringAsFixed(1)}s, '
            '${node.value.toStringAsFixed(1)}${widget.recipe.unitLabel}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        return GestureDetector(
          onTapUp: (details) =>
              _handleTap(details.localPosition, size),
          onPanStart: (details) =>
              _handleDragStart(details.localPosition, size),
          onPanUpdate: (details) =>
              _handleDragUpdate(details.localPosition, size),
          onPanEnd: (_) => _handleDragEnd(),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ProfileGraph(recipe: widget.recipe),
              _buildHighlightOverlay(size),
              _buildDragTooltip(size),
            ],
          ),
        );
      },
    );
  }
}
