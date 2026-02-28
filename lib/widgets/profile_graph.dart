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

/// 추출 시뮬레이션 그래프
///
/// X축 = 시간(s), 모든 메트릭을 정규화(0~10)하여 하나의 차트에 표시.
/// 압력/유량 (파란색): 설정값 + 랜덤 노이즈
/// 추출량 (갈색): 시간에 따라 점진적 증가
/// 온도 (빨간색): 25℃ → 타깃 상승 후 ±1~2℃ 오실레이션
class SimulationGraph extends StatelessWidget {
  final EspressoRecipe recipe;

  const SimulationGraph({super.key, required this.recipe});

  static const Color pressureColor = Color(0xFF2196F3); // blue
  static const Color yieldColor = Color(0xFF795548); // brown
  static const Color tempColor = Color(0xFFFF5722); // red-orange
  static const Color gridColor = Color(0xFFE0E0E0);
  static const Color textColor = Color(0xFF616161);

  static const double _dt = 0.4;
  static const double _pressureFlowK = 0.12;

  @override
  Widget build(BuildContext context) {
    final sim = _generateSimulation();
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, right: 8),
          child: LineChart(_buildChart(sim)),
        ),
        Positioned(
          top: 4,
          right: 12,
          child: _buildLegend(sim),
        ),
      ],
    );
  }

  Widget _buildLegend(_SimData sim) {
    final pressLabel = recipe.profileMode == ProfileMode.pressure
        ? '압력'
        : '유량';
    final yieldLabel =
        '추출량 (${sim.yieldMax.toStringAsFixed(0)}g=100%)';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: gridColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _legendItem(pressureColor, pressLabel),
          _legendItem(yieldColor, yieldLabel),
          _legendItem(tempColor, '온도'),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 3,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(fontSize: 8, color: textColor)),
        ],
      ),
    );
  }

  _SimData _generateSimulation() {
    final maxT = recipe.maxShotTime;
    final endW = recipe.endWeight > 0 ? recipe.endWeight : 50.0;
    final targetTemp = recipe.temperature;
    final rng = Random(42);

    final pressMax = recipe.yAxisMax;
    const double tempMin = 20.0;
    const double tempMax = 100.0;

    final pressureSpots = <FlSpot>[];
    final yieldSpots = <FlSpot>[];
    final tempSpots = <FlSpot>[];

    double cumYield = 0;

    // maxShotTime 넘어서도 endWeight 도달까지 시뮬레이션 연장
    // 안전 한도: maxT * 3 (무한루프 방지)
    final simLimit = maxT * 3;
    double stopT = maxT;

    for (int i = 0; ; i++) {
      final t = i * _dt;
      if (t > simLimit) break;

      // ── 압력/유량 ──
      final profileVal = ProfileGraph.profileValueAt(recipe, t);
      final noise = (rng.nextDouble() - 0.5) * 0.6;
      final actualPressure = (profileVal + noise).clamp(0.0, pressMax);
      pressureSpots.add(FlSpot(t, actualPressure / pressMax * 10));

      // ── 추출량 ──
      if (i > 0) {
        final actualDt = _dt;
        final flowRate = recipe.profileMode == ProfileMode.pressure
            ? profileVal * _pressureFlowK
            : profileVal;
        final yieldNoise = 1.0 + (rng.nextDouble() - 0.5) * 0.1;
        cumYield += flowRate * actualDt * yieldNoise;
        if (recipe.endWeight > 0 && cumYield >= endW) {
          cumYield = endW;
          // 100% 도달 → 이 스텝까지 기록 후 종료
          yieldSpots.add(FlSpot(t, 10.0));
          // 온도도 마지막 스텝 기록
          double temp;
          const rampTime = 8.0;
          if (t < rampTime) {
            final frac = 1.0 - exp(-3.0 * t / rampTime);
            temp = 25.0 + (targetTemp - 25.0) * frac;
          } else {
            final osc = sin(t * 0.8) * (1.0 + rng.nextDouble());
            temp = targetTemp + osc;
          }
          temp = temp.clamp(tempMin, tempMax);
          tempSpots.add(
              FlSpot(t, (temp - tempMin) / (tempMax - tempMin) * 10));
          stopT = t;
          break;
        }
      }
      yieldSpots.add(FlSpot(t, (cumYield / endW * 10).clamp(0.0, 10.0)));

      // ── 온도 ──
      double temp;
      const rampTime = 8.0;
      if (t < rampTime) {
        final frac = 1.0 - exp(-3.0 * t / rampTime);
        temp = 25.0 + (targetTemp - 25.0) * frac;
      } else {
        final osc = sin(t * 0.8) * (1.0 + rng.nextDouble());
        temp = targetTemp + osc;
      }
      temp = temp.clamp(tempMin, tempMax);
      tempSpots
          .add(FlSpot(t, (temp - tempMin) / (tempMax - tempMin) * 10));
    }

    return _SimData(
      pressureSpots: pressureSpots,
      yieldSpots: yieldSpots,
      tempSpots: tempSpots,
      maxT: stopT,
      yieldMax: endW,
    );
  }

  LineChartData _buildChart(_SimData sim) {
    final pressMax = recipe.yAxisMax;
    final pressUnit =
        recipe.profileMode == ProfileMode.pressure ? 'bar' : 'ml/s';

    return LineChartData(
      minX: 0,
      maxX: sim.maxT,
      minY: 0,
      maxY: 10,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        horizontalInterval: 2.5,
        verticalInterval: sim.maxT / 5,
        getDrawingHorizontalLine: (_) =>
            FlLine(color: gridColor, strokeWidth: 0.5),
        getDrawingVerticalLine: (_) =>
            FlLine(color: gridColor, strokeWidth: 0.5),
      ),
      titlesData: _buildTitles(sim.maxT, pressMax, pressUnit),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: gridColor, width: 1),
      ),
      lineBarsData: [
        // 압력/유량
        LineChartBarData(
          spots: sim.pressureSpots,
          isCurved: true,
          curveSmoothness: 0.15,
          preventCurveOverShooting: true,
          color: pressureColor,
          barWidth: 2,
          dotData: const FlDotData(show: false),
        ),
        // 추출량
        LineChartBarData(
          spots: sim.yieldSpots,
          isCurved: true,
          curveSmoothness: 0.15,
          preventCurveOverShooting: true,
          color: yieldColor,
          barWidth: 2,
          dotData: const FlDotData(show: false),
        ),
        // 온도
        LineChartBarData(
          spots: sim.tempSpots,
          isCurved: true,
          curveSmoothness: 0.15,
          preventCurveOverShooting: true,
          color: tempColor,
          barWidth: 2,
          dotData: const FlDotData(show: false),
        ),
      ],
      lineTouchData: const LineTouchData(enabled: false),
    );
  }

  FlTitlesData _buildTitles(
      double maxX, double pressMax, String pressUnit) {
    const double tempMin = 20.0;
    const double tempMax = 100.0;

    return FlTitlesData(
      topTitles:
          const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 34,
          interval: 2.5,
          getTitlesWidget: (value, meta) {
            if (value == meta.max || value == meta.min) {
              return const SizedBox.shrink();
            }
            final pct = (value / 10 * 100).toInt();
            return Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                '$pct%',
                style: const TextStyle(
                    fontSize: 9,
                    color: yieldColor,
                    fontWeight: FontWeight.w500),
              ),
            );
          },
        ),
      ),
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
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 44,
          interval: 2.5,
          getTitlesWidget: (value, meta) {
            if (value == meta.max || value == meta.min) {
              return const SizedBox.shrink();
            }
            final pressVal = value / 10 * pressMax;
            final tempVal =
                tempMin + value / 10 * (tempMax - tempMin);
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${pressVal.toStringAsFixed(0)}$pressUnit',
                    style: const TextStyle(
                        fontSize: 8, color: pressureColor),
                  ),
                  Text(
                    '${tempVal.toStringAsFixed(0)}℃',
                    style:
                        const TextStyle(fontSize: 8, color: tempColor),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SimData {
  final List<FlSpot> pressureSpots;
  final List<FlSpot> yieldSpots;
  final List<FlSpot> tempSpots;
  final double maxT;
  final double yieldMax;

  _SimData({
    required this.pressureSpots,
    required this.yieldSpots,
    required this.tempSpots,
    required this.maxT,
    required this.yieldMax,
  });
}
