import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/espresso_recipe.dart';

/// 에스프레소 프로파일 프리뷰 그래프 위젯
///
/// 3구간: Pre-infusion(녹색) → Transition(점선) → Extraction(노란색)
/// 각 구간의 램프 타입(Linear/Exponential) 반영.
class ProfileGraph extends StatelessWidget {
  final EspressoRecipe recipe;

  const ProfileGraph({super.key, required this.recipe});

  static const Color preInfusionColor = Color(0xFF4CAF50);
  static const Color extractionColor = Color(0xFFFFC107);
  static const Color transitionColor = Color(0xFF9E9E9E);
  static const Color preInfusionFill = Color(0x404CAF50);
  static const Color extractionFill = Color(0x40FFC107);
  static const Color gridColor = Color(0xFFE0E0E0);
  static const Color textColor = Color(0xFF616161);

  /// 커브 포인트 수 (exponential 시 부드러운 곡선용)
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
        horizontalInterval: recipe.profileMode == ProfileMode.pressure ? 3 : 2,
        verticalInterval: maxX / 5,
        getDrawingHorizontalLine: (_) => FlLine(
          color: gridColor,
          strokeWidth: 0.5,
        ),
        getDrawingVerticalLine: (_) => FlLine(
          color: gridColor,
          strokeWidth: 0.5,
        ),
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
    final double transEnd = piEnd + recipe.transitionTime;

    return ExtraLinesData(
      verticalLines: [
        // PI 종료 지점
        VerticalLine(
          x: piEnd,
          color: preInfusionColor.withValues(alpha: 0.4),
          strokeWidth: 1,
          dashArray: [4, 4],
          label: VerticalLineLabel(
            show: true,
            alignment: Alignment.topRight,
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            style: const TextStyle(fontSize: 10, color: textColor),
            labelResolver: (_) => 'PI ${piEnd.toStringAsFixed(1)}s',
          ),
        ),
        // 전환 종료 지점 (전환 시간이 0보다 클 때만)
        if (recipe.transitionTime > 0)
          VerticalLine(
            x: transEnd,
            color: transitionColor.withValues(alpha: 0.3),
            strokeWidth: 1,
            dashArray: [2, 4],
          ),
      ],
    );
  }

  FlTitlesData _buildTitles(double maxX) {
    return FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
          interval: recipe.profileMode == ProfileMode.pressure ? 3 : 2,
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
  ///
  /// [rampType] linear: 직선, exponential: 1 - e^(-3t/T) 형태
  /// [startTime] ~ [endTime] 구간, [startY] ~ [endY] 범위
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
      return [
        FlSpot(startTime, startY),
        FlSpot(endTime, endY),
      ];
    }

    // Exponential: 1 - e^(-k*t), k=4 → t=1일 때 ~98% 도달
    const double k = 4.0;
    final List<FlSpot> spots = [];
    for (int i = 0; i <= _curveResolution; i++) {
      final t = i / _curveResolution; // 0.0 ~ 1.0
      final x = startTime + duration * t;
      final factor = 1.0 - exp(-k * t);
      final y = startY + deltaY * factor;
      spots.add(FlSpot(x, y));
    }
    return spots;
  }

  List<LineChartBarData> _buildLineBars() {
    final double piTime = recipe.preInfusionTime;
    final double piTarget = recipe.preInfusionTarget;
    final double exTarget = recipe.extractionTarget;
    final double maxX = recipe.maxShotTime;
    final double transTime = recipe.transitionTime;
    final bool hasPI = recipe.hasPreInfusion;

    final List<LineChartBarData> bars = [];

    if (hasPI) {
      // 1) Pre-infusion: 0 → piTarget (녹색)
      final piSpots = _generateRampSpots(
        startTime: 0,
        endTime: piTime,
        startY: 0,
        endY: piTarget,
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

      // 2) Transition: piTarget → exTarget (회색 점선 램프)
      if (transTime > 0) {
        final transSpots = _generateRampSpots(
          startTime: piTime,
          endTime: piTime + transTime,
          startY: piTarget,
          endY: exTarget,
          rampType: recipe.extractionRampType,
        );
        bars.add(LineChartBarData(
          spots: transSpots,
          isCurved: recipe.extractionRampType == RampType.exponential,
          preventCurveOverShooting: true,
          color: transitionColor,
          barWidth: 2,
          dashArray: [6, 4],
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ));
      }

      // 3) Extraction: exTarget 유지 (노란색)
      final exStart = piTime + transTime;
      if (exStart < maxX) {
        bars.add(LineChartBarData(
          spots: [
            FlSpot(exStart, exTarget),
            FlSpot(maxX, exTarget),
          ],
          isCurved: false,
          color: extractionColor,
          barWidth: 2.5,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: true, color: extractionFill),
        ));
      }
    } else {
      // PI 없음 — 0에서 바로 exTarget으로 램프 후 유지
      final rampEnd = min(2.0, maxX * 0.1); // 초반 짧은 램프
      final rampSpots = _generateRampSpots(
        startTime: 0,
        endTime: rampEnd,
        startY: 0,
        endY: exTarget,
        rampType: recipe.extractionRampType,
      );

      // 램프 + 유지를 하나의 라인으로
      final allSpots = [
        ...rampSpots,
        if (rampEnd < maxX) FlSpot(maxX, exTarget),
      ];

      bars.add(LineChartBarData(
        spots: allSpots,
        isCurved: recipe.extractionRampType == RampType.exponential,
        preventCurveOverShooting: true,
        color: extractionColor,
        barWidth: 2.5,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: true, color: extractionFill),
      ));
    }

    return bars;
  }
}
