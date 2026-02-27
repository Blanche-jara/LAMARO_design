import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/espresso_recipe.dart';

/// 에스프레소 프로파일 프리뷰 그래프 위젯
///
/// Pre-infusion (녹색) → 자동 전환 → Extraction + 변곡점 (노란색)
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

    final double piEnd = recipe.preInfusionTime;

    return ExtraLinesData(
      verticalLines: [
        VerticalLine(
          x: piEnd,
          color: preInfusionColor.withValues(alpha: 0.4),
          strokeWidth: 1,
          dashArray: [4, 4],
          label: VerticalLineLabel(
            show: true,
            alignment: Alignment.topRight,
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            style: const TextStyle(fontSize: 9, color: textColor),
            labelResolver: (_) => 'S1 ${piEnd.toStringAsFixed(1)}s',
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

  /// 램프 커브 포인트 생성
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

  List<LineChartBarData> _buildLineBars() {
    final double maxX = recipe.maxShotTime;
    final bool hasPI = recipe.hasPreInfusion;
    final List<LineChartBarData> bars = [];

    double cursor = 0;
    double currentValue = 0;

    // Pre-infusion (녹색)
    if (hasPI) {
      final piEnd = min(cursor + recipe.preInfusionTime, maxX);
      final piSpots = _generateRampSpots(
        startTime: cursor,
        endTime: piEnd,
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
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: true, color: preInfusionFill),
      ));
      cursor = piEnd;
      currentValue = recipe.preInfusionTarget;
    }

    // Extraction + Waypoints (노란색)
    if (cursor < maxX) {
      bars.addAll(_buildExtractionBars(cursor, currentValue));
    }

    return bars;
  }

  /// 시간 t에서의 프로파일 값 (압력/유량) 계산
  ///
  /// 모든 스테이지를 duration 기반으로 순차 처리.
  static double profileValueAt(EspressoRecipe recipe, double t) {
    if (t <= 0) return 0;

    double cursor = 0;
    double prevValue = 0;

    // PI
    final piTime = recipe.preInfusionTime;
    if (piTime > 0) {
      if (t <= cursor + piTime) {
        final frac = (t - cursor) / piTime;
        return _applyRamp(
            frac, 0, recipe.preInfusionTarget, recipe.preInfusionRampType);
      }
      cursor += piTime;
      prevValue = recipe.preInfusionTarget;
    }

    // Extraction
    final extTime = recipe.extractionTime;
    if (extTime > 0 && t <= cursor + extTime) {
      final frac = (t - cursor) / extTime;
      return _applyRamp(
          frac, prevValue, recipe.extractionTarget, recipe.extractionRampType);
    }
    cursor += extTime;
    prevValue = recipe.extractionTarget;

    // Waypoints (순서대로)
    for (final wp in recipe.waypoints) {
      if (wp.duration > 0 && t <= cursor + wp.duration) {
        final frac = (t - cursor) / wp.duration;
        return _applyRamp(frac, prevValue, wp.targetValue, wp.rampType);
      }
      cursor += wp.duration;
      prevValue = wp.targetValue;
    }

    return prevValue; // 마지막 스테이지 값 유지
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

  /// Extraction + Waypoints 라인 생성 (duration 기반 순차 처리)
  List<LineChartBarData> _buildExtractionBars(
    double startTime,
    double startValue,
  ) {
    final maxX = recipe.maxShotTime;
    if (startTime >= maxX) return [];

    final List<FlSpot> allSpots = [];
    final List<double> stageBoundaries = [];

    double cursor = startTime;
    double currentValue = startValue;

    // Extraction 램프
    final extEnd = min(cursor + recipe.extractionTime, maxX);
    final extSpots = _generateRampSpots(
      startTime: cursor,
      endTime: extEnd,
      startY: currentValue,
      endY: recipe.extractionTarget,
      rampType: recipe.extractionRampType,
    );
    allSpots.addAll(extSpots);
    cursor = extEnd;
    currentValue = recipe.extractionTarget;

    // Waypoints (순서대로)
    for (final wp in recipe.waypoints) {
      if (cursor >= maxX) break;
      stageBoundaries.add(cursor);
      final wpEnd = min(cursor + wp.duration, maxX);
      final spots = _generateRampSpots(
        startTime: cursor,
        endTime: wpEnd,
        startY: currentValue,
        endY: wp.targetValue,
        rampType: wp.rampType,
      );
      if (allSpots.isNotEmpty && spots.isNotEmpty) {
        spots.removeAt(0);
      }
      allSpots.addAll(spots);
      cursor = wpEnd;
      currentValue = wp.targetValue;
    }

    // 마지막 값 → maxShotTime까지 유지
    if (cursor < maxX) {
      if (allSpots.isEmpty) {
        allSpots.add(FlSpot(cursor, currentValue));
      }
      allSpots.add(FlSpot(maxX, currentValue));
    }

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
          show: stageBoundaries.isNotEmpty,
          getDotPainter: (spot, percent, bar, index) {
            final isBoundary = stageBoundaries
                .any((t) => (t - spot.x).abs() < 0.01);
            if (!isBoundary) {
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
