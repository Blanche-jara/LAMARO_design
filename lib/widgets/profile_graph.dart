import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/espresso_recipe.dart';

/// 에스프레소 프로파일 프리뷰 그래프 위젯
///
/// 각 노드는 그래프 상의 좌표점 (시간, 타깃).
/// Pre-infusion (녹색) → Extraction + 변곡점 (노란색)
/// 노드 간 커브: Linear 또는 Exponential.
class ProfileGraph extends StatelessWidget {
  final EspressoRecipe recipe;

  const ProfileGraph({super.key, required this.recipe});

  static const Color preInfusionColor = Color(0xFF4CAF50);
  static const Color extractionColor = Color(0xFFFFC107);
  static const Color preInfusionFill = Color(0x404CAF50);
  static const Color extractionFill = Color(0x40FFC107);
  static const Color gridColor = Color(0xFFE0E0E0);
  static const Color textColor = Color(0xFF616161);

  static const int _curveResolution = 20;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, right: 8),
          child: LineChart(_buildChart()),
        ),
        Positioned(
          top: 8,
          right: 12,
          child: _buildTemperatureBadge(),
        ),
        Positioned(
          bottom: 28,
          right: 12,
          child: _buildEndWeightLabel(),
        ),
      ],
    );
  }

  Widget _buildTemperatureBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFF5722).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFFF5722).withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Text(
        '${recipe.temperature.toStringAsFixed(1)}℃',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFFFF5722),
        ),
      ),
    );
  }

  Widget _buildEndWeightLabel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.blueGrey.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        '${recipe.endWeight.toStringAsFixed(1)}g',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.blueGrey,
        ),
      ),
    );
  }

  LineChartData _buildChart() {
    final double maxX = recipe.maxShotTime;
    final double maxY = recipe.yAxisMax;

    return LineChartData(
      minX: 0,
      maxX: maxX,
      minY: 0,
      maxY: maxY,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        horizontalInterval:
            recipe.profileMode == ProfileMode.pressure ? 3 : 2,
        verticalInterval: maxX / 5,
        getDrawingHorizontalLine: (_) =>
            FlLine(color: gridColor, strokeWidth: 0.5),
        getDrawingVerticalLine: (_) =>
            FlLine(color: gridColor, strokeWidth: 0.5),
      ),
      titlesData: _buildTitles(maxX),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: gridColor, width: 1),
      ),
      lineBarsData: _buildLineBars(),
      lineTouchData: const LineTouchData(enabled: false),
      extraLinesData: _buildExtraLines(),
    );
  }

  ExtraLinesData _buildExtraLines() {
    if (!recipe.hasPreInfusion) return const ExtraLinesData();

    final double piTime = recipe.preInfusionTime;

    return ExtraLinesData(
      verticalLines: [
        VerticalLine(
          x: piTime,
          color: preInfusionColor.withValues(alpha: 0.4),
          strokeWidth: 1,
          dashArray: [4, 4],
          label: VerticalLineLabel(
            show: true,
            alignment: Alignment.topRight,
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            style: const TextStyle(fontSize: 9, color: textColor),
            labelResolver: (_) => 'N1 ${piTime.toStringAsFixed(1)}s',
          ),
        ),
      ],
    );
  }

  FlTitlesData _buildTitles(double maxX) {
    return FlTitlesData(
      topTitles:
          const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles:
          const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
        axisNameWidget: const Text(
          'Time (s)',
          style: TextStyle(fontSize: 11, color: textColor),
        ),
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 28,
          interval: maxX / 5,
          getTitlesWidget: (value, meta) {
            if (value == meta.max || value == meta.min) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                value.toStringAsFixed(0),
                style: const TextStyle(fontSize: 10, color: textColor),
              ),
            );
          },
        ),
      ),
      leftTitles: AxisTitles(
        axisNameWidget: Text(
          recipe.unitLabel,
          style: const TextStyle(fontSize: 11, color: textColor),
        ),
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 36,
          interval:
              recipe.profileMode == ProfileMode.pressure ? 3 : 2,
          getTitlesWidget: (value, meta) {
            if (value == meta.max || value == meta.min) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                value.toStringAsFixed(0),
                style: const TextStyle(fontSize: 10, color: textColor),
              ),
            );
          },
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // 램프 커브 포인트 생성
  // ─────────────────────────────────────────────

  /// 두 노드 사이의 커브 포인트 생성
  List<FlSpot> _generateRampSpots({
    required double startTime,
    required double endTime,
    required double startY,
    required double endY,
    required RampType rampType,
  }) {
    if (startTime >= endTime) return [FlSpot(startTime, endY)];

    final duration = endTime - startTime;
    final deltaY = endY - startY;

    if (rampType == RampType.linear) {
      return [FlSpot(startTime, startY), FlSpot(endTime, endY)];
    }

    // Exponential: 1 - e^(-k*t), k=4
    const double k = 4.0;
    final List<FlSpot> spots = [];
    for (int i = 0; i <= _curveResolution; i++) {
      final t = i / _curveResolution;
      final x = startTime + duration * t;
      final factor = 1.0 - exp(-k * t);
      final y = startY + deltaY * factor;
      spots.add(FlSpot(x, y));
    }
    return spots;
  }

  // ─────────────────────────────────────────────
  // 라인 바 생성 (절대 좌표 노드 기반)
  // ─────────────────────────────────────────────

  List<LineChartBarData> _buildLineBars() {
    final double maxX = recipe.maxShotTime;
    final bool hasPI = recipe.hasPreInfusion;
    final List<LineChartBarData> bars = [];

    double cursor = 0;
    double currentValue = 0;

    // Pre-infusion (녹색): (0, 0) → (piTime, piTarget)
    if (hasPI) {
      final piTime = min(recipe.preInfusionTime, maxX);
      final piSpots = _generateRampSpots(
        startTime: 0,
        endTime: piTime,
        startY: 0,
        endY: recipe.preInfusionTarget,
        rampType: recipe.preInfusionRampType,
      );
      bars.add(LineChartBarData(
        spots: piSpots,
        isCurved: recipe.preInfusionRampType == RampType.exponential,
        preventCurveOverShooting: true,
        color: preInfusionColor,
        barWidth: 2.5,
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, bar, index) {
            // PI 노드 좌표에 점 표시 (마지막 스폿)
            if (index == piSpots.length - 1) {
              return FlDotCirclePainter(
                radius: 4,
                color: preInfusionColor,
                strokeWidth: 2,
                strokeColor: Colors.white,
              );
            }
            return FlDotCirclePainter(
              radius: 0,
              color: Colors.transparent,
              strokeColor: Colors.transparent,
            );
          },
        ),
        belowBarData: BarAreaData(show: true, color: preInfusionFill),
      ));
      cursor = piTime;
      currentValue = recipe.preInfusionTarget;
    }

    // Extraction + Waypoints (노란색)
    if (cursor < maxX) {
      bars.addAll(_buildExtractionBars(cursor, currentValue));
    }

    return bars;
  }

  /// Extraction + Waypoints 라인 생성 (절대 좌표 노드 기반)
  List<LineChartBarData> _buildExtractionBars(
    double startTime,
    double startValue,
  ) {
    final maxX = recipe.maxShotTime;
    if (startTime >= maxX) return [];

    final List<FlSpot> allSpots = [];
    final List<double> nodeXCoords = [];

    double cursor = startTime;
    double currentValue = startValue;

    // 노드 목록: Extraction + Waypoints (절대 시간 좌표)
    final nodes = <({double time, double target, RampType rampType})>[
      (
        time: recipe.extractionTime,
        target: recipe.extractionTarget,
        rampType: recipe.extractionRampType,
      ),
      ...recipe.waypoints.map((wp) => (
            time: wp.time,
            target: wp.targetValue,
            rampType: wp.rampType,
          )),
    ];

    for (final node in nodes) {
      if (cursor >= maxX) break;

      final nodeTime = min(node.time, maxX);
      nodeXCoords.add(nodeTime);

      final spots = _generateRampSpots(
        startTime: cursor,
        endTime: nodeTime,
        startY: currentValue,
        endY: node.target,
        rampType: node.rampType,
      );

      // 이전 스폿과 중복 방지
      if (allSpots.isNotEmpty && spots.isNotEmpty) {
        spots.removeAt(0);
      }
      allSpots.addAll(spots);

      cursor = nodeTime;
      currentValue = node.target;
    }

    // 마지막 노드 → maxShotTime까지 유지
    if (cursor < maxX) {
      if (allSpots.isEmpty) {
        allSpots.add(FlSpot(cursor, currentValue));
      }
      allSpots.add(FlSpot(maxX, currentValue));
    }

    if (allSpots.length < 2) return [];

    final hasExpo =
        recipe.extractionRampType == RampType.exponential ||
            recipe.waypoints.any((w) => w.rampType == RampType.exponential);

    return [
      LineChartBarData(
        spots: allSpots,
        isCurved: hasExpo,
        preventCurveOverShooting: true,
        curveSmoothness: 0.2,
        color: extractionColor,
        barWidth: 2.5,
        dotData: FlDotData(
          show: nodeXCoords.isNotEmpty,
          getDotPainter: (spot, percent, bar, index) {
            final isNode = nodeXCoords
                .any((t) => (t - spot.x).abs() < 0.01);
            if (!isNode) {
              return FlDotCirclePainter(
                radius: 0,
                color: Colors.transparent,
                strokeColor: Colors.transparent,
              );
            }
            return FlDotCirclePainter(
              radius: 4,
              color: extractionColor,
              strokeWidth: 2,
              strokeColor: Colors.white,
            );
          },
        ),
        belowBarData: BarAreaData(show: true, color: extractionFill),
      ),
    ];
  }

  // ─────────────────────────────────────────────
  // 프로파일 값 계산 (절대 좌표 노드 보간)
  // ─────────────────────────────────────────────

  /// 시간 t에서의 프로파일 값 (압력/유량)
  ///
  /// 노드 = 그래프 상의 좌표점. 노드 간 Lin/Exp 보간.
  /// 마지막 노드 이후: 해당 값 유지.
  static double profileValueAt(EspressoRecipe recipe, double t) {
    if (t <= 0) return 0;

    // 노드 목록 구축: (절대시간, 타깃, 커브)
    final nodes = <({double time, double target, RampType rampType})>[];

    if (recipe.hasPreInfusion) {
      nodes.add((
        time: recipe.preInfusionTime,
        target: recipe.preInfusionTarget,
        rampType: recipe.preInfusionRampType,
      ));
    }
    nodes.add((
      time: recipe.extractionTime,
      target: recipe.extractionTarget,
      rampType: recipe.extractionRampType,
    ));
    for (final wp in recipe.waypoints) {
      nodes.add((
        time: wp.time,
        target: wp.targetValue,
        rampType: wp.rampType,
      ));
    }

    double prevTime = 0;
    double prevValue = 0;

    for (final node in nodes) {
      if (t <= node.time) {
        final duration = node.time - prevTime;
        if (duration <= 0) return node.target;
        final frac = (t - prevTime) / duration;
        return _applyRamp(frac, prevValue, node.target, node.rampType);
      }
      prevTime = node.time;
      prevValue = node.target;
    }

    // 마지막 노드 이후: 값 유지
    return prevValue;
  }

  static double _applyRamp(
      double fraction, double from, double to, RampType rampType) {
    fraction = fraction.clamp(0.0, 1.0);
    if (rampType == RampType.linear) {
      return from + (to - from) * fraction;
    }
    const k = 4.0;
    final factor = 1.0 - exp(-k * fraction);
    return from + (to - from) * factor;
  }
}

/// 추출량(Yield) 기반 프로파일 그래프
///
/// X축 = 누적 추출량(g), Y축 = 압력(bar) 또는 유량(ml/s)
/// Pre-infusion 구간에서도 소량의 추출이 발생하므로 녹색으로 표시.
class YieldGraph extends StatelessWidget {
  final EspressoRecipe recipe;

  const YieldGraph({super.key, required this.recipe});

  static const double _dt = 0.15;
  // 압력→유량 변환 상수 (g/s per bar, 대략적 모델)
  static const double _pressureFlowK = 0.12;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, right: 8),
      child: LineChart(_buildChart()),
    );
  }

  double _flowRate(double profileValue) {
    return recipe.profileMode == ProfileMode.pressure
        ? profileValue * _pressureFlowK
        : profileValue;
  }

  LineChartData _buildChart() {
    final maxT = recipe.maxShotTime;
    final piTime = recipe.preInfusionTime;
    final hasPI = recipe.hasPreInfusion;
    final maxY = recipe.yAxisMax;

    final endW = recipe.endWeight;
    final piSpots = <FlSpot>[];
    final exSpots = <FlSpot>[];
    double cumYield = 0;
    double prevValue = 0;

    final int steps = (maxT / _dt).ceil();
    for (int i = 0; i <= steps; i++) {
      final t = min(i * _dt, maxT);
      final value = ProfileGraph.profileValueAt(recipe, t);

      // 사다리꼴 적분
      if (i > 0) {
        final prevT = min((i - 1) * _dt, maxT);
        final actualDt = t - prevT;
        cumYield +=
            (_flowRate(prevValue) + _flowRate(value)) * 0.5 * actualDt;
      }

      // endWeight 도달 시 정확히 endWeight 지점에서 종료
      if (endW > 0 && cumYield >= endW) {
        final endSpot = FlSpot(endW, value);
        if (hasPI && t <= piTime) {
          piSpots.add(endSpot);
        } else {
          if (exSpots.isEmpty && piSpots.isNotEmpty) {
            exSpots.add(piSpots.last);
          }
          exSpots.add(endSpot);
        }
        cumYield = endW;
        break;
      }

      final spot = FlSpot(cumYield, value);
      if (hasPI && t <= piTime) {
        piSpots.add(spot);
      } else {
        if (exSpots.isEmpty && piSpots.isNotEmpty) {
          exSpots.add(piSpots.last); // 연속성
        }
        exSpots.add(spot);
      }

      prevValue = value;
    }

    // maxShotTime 내에 endWeight 미달 시 마지막 값으로 연장
    if (endW > 0 && cumYield < endW && prevValue > 0) {
      final rate = _flowRate(prevValue);
      if (rate > 0.001) {
        final endSpot = FlSpot(endW, prevValue);
        if (exSpots.isNotEmpty) {
          exSpots.add(endSpot);
        } else if (piSpots.isNotEmpty) {
          piSpots.add(endSpot);
        }
        cumYield = endW;
      }
    }

    final totalYield = cumYield;
    final xCeil = endW > 0
        ? endW * 1.05
        : totalYield > 0.5
            ? totalYield * 1.05
            : 1.0;

    final bars = <LineChartBarData>[];
    if (piSpots.length > 1) {
      bars.add(LineChartBarData(
        spots: piSpots,
        isCurved: false,
        color: ProfileGraph.preInfusionColor,
        barWidth: 2.5,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
            show: true, color: ProfileGraph.preInfusionFill),
      ));
    }
    if (exSpots.length > 1) {
      bars.add(LineChartBarData(
        spots: exSpots,
        isCurved: false,
        color: ProfileGraph.extractionColor,
        barWidth: 2.5,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
            show: true, color: ProfileGraph.extractionFill),
      ));
    }

    return LineChartData(
      minX: 0,
      maxX: xCeil,
      minY: 0,
      maxY: maxY,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        horizontalInterval:
            recipe.profileMode == ProfileMode.pressure ? 3 : 2,
        verticalInterval: xCeil / 5,
        getDrawingHorizontalLine: (_) =>
            FlLine(color: ProfileGraph.gridColor, strokeWidth: 0.5),
        getDrawingVerticalLine: (_) =>
            FlLine(color: ProfileGraph.gridColor, strokeWidth: 0.5),
      ),
      titlesData: _buildTitles(xCeil),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: ProfileGraph.gridColor, width: 1),
      ),
      lineBarsData: bars,
      lineTouchData: const LineTouchData(enabled: false),
      extraLinesData: _buildExtraLines(xCeil),
    );
  }

  ExtraLinesData _buildExtraLines(double maxX) {
    final ew = recipe.endWeight;
    if (ew <= 0 || ew >= maxX) return const ExtraLinesData();

    return ExtraLinesData(
      verticalLines: [
        VerticalLine(
          x: ew,
          color: Colors.blueGrey.withValues(alpha: 0.6),
          strokeWidth: 1.5,
          dashArray: [4, 4],
          label: VerticalLineLabel(
            show: true,
            alignment: Alignment.topLeft,
            padding: const EdgeInsets.only(right: 4, bottom: 4),
            style: const TextStyle(
                fontSize: 9, color: ProfileGraph.textColor),
            labelResolver: (_) => '${ew.toStringAsFixed(0)}g',
          ),
        ),
      ],
    );
  }

  FlTitlesData _buildTitles(double maxX) {
    return FlTitlesData(
      topTitles:
          const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles:
          const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
        axisNameWidget: const Text(
          'Yield (g)',
          style: TextStyle(fontSize: 11, color: ProfileGraph.textColor),
        ),
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 28,
          interval: maxX / 5,
          getTitlesWidget: (value, meta) {
            if (value == meta.max || value == meta.min) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                value.toStringAsFixed(0),
                style: const TextStyle(
                    fontSize: 10, color: ProfileGraph.textColor),
              ),
            );
          },
        ),
      ),
      leftTitles: AxisTitles(
        axisNameWidget: Text(
          recipe.unitLabel,
          style: const TextStyle(
              fontSize: 11, color: ProfileGraph.textColor),
        ),
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 36,
          interval:
              recipe.profileMode == ProfileMode.pressure ? 3 : 2,
          getTitlesWidget: (value, meta) {
            if (value == meta.max || value == meta.min) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                value.toStringAsFixed(0),
                style: const TextStyle(
                    fontSize: 10, color: ProfileGraph.textColor),
              ),
            );
          },
        ),
      ),
    );
  }
}
