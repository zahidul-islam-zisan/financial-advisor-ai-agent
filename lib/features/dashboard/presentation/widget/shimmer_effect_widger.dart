import 'package:expense_tracker_app/core/constants/app_colors.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerEffectWidger {
  static Widget shimmerEffectSummary() {
    return Shimmer.fromColors(
      baseColor: AppColors.primary.withAlpha(30),
      highlightColor: Colors.grey.shade100.withAlpha(30),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Column(
            children: [
              Container(height: 14, width: 60, color: Colors.white),
              const SizedBox(height: 5),
              Container(height: 16, width: 40, color: Colors.white),
            ],
          ),
          const SizedBox(width: 10),
          Column(
            children: [
              Container(height: 14, width: 60, color: Colors.white),
              const SizedBox(height: 5),
              Container(height: 16, width: 40, color: Colors.white),
            ],
          ),
          const SizedBox(width: 10),
          Column(
            children: [
              Container(height: 14, width: 60, color: Colors.white),
              const SizedBox(height: 5),
              Container(height: 16, width: 40, color: Colors.white),
            ],
          ),
        ],
      ),
    );
  }

  //shimmer effect for chart loading
  static Widget shimmerEffectChart() {
    return Shimmer.fromColors(
      baseColor: AppColors.primary.withAlpha(30),
      highlightColor: Colors.grey.shade100.withAlpha(30),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: PieChart(
              PieChartData(
                borderData: FlBorderData(show: false),
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: [
                  PieChartSectionData(
                    color: Colors.white,
                    value: 100,
                    title: '100%',
                    radius: 50,
                    titleStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 14, width: 60, color: Colors.white),
                  const SizedBox(height: 5),
                  Container(height: 16, width: 40, color: Colors.white),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
