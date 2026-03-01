import 'package:flutter/material.dart';

class TimeFrameButtonsWidget extends StatelessWidget {
  final String selectedTimeFrame;
  final Function(String) onTimeFrameChanged;

  const TimeFrameButtonsWidget({
    super.key,
    required this.selectedTimeFrame,
    required this.onTimeFrameChanged,
  });

  @override
  Widget build(BuildContext context) {
    final timeFrames = ['Live', '1H', '1D', '1W', '1M', '3M'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: timeFrames.map((timeFrame) {
          final isSelected = selectedTimeFrame == timeFrame;
          return GestureDetector(
            onTap: () => onTimeFrameChanged(timeFrame),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF1E3A8A)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: isSelected
                    ? Border.all(color: const Color(0xFF3B82F6), width: 1)
                    : null,
              ),
              child: Text(
                timeFrame,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white.withOpacity(0.5),
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
