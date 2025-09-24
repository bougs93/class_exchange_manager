import 'package:flutter/material.dart';
import '../models/time_slot.dart';
import 'exchange_algorithm.dart';
import 'constants.dart';

/// 교체 가능한 시간을 시각적으로 표시하는 클래스
class ExchangeVisualizer {
  
  /// 교체 가능한 시간에 표시할 아이콘
  static Widget? getExchangeIcon(TimeSlot slot, List<ExchangeOption> exchangeOptions) {
    ExchangeOption? option = exchangeOptions.firstWhere(
      (opt) => opt.timeSlot.dayOfWeek == slot.dayOfWeek && 
               opt.timeSlot.period == slot.period &&
               opt.timeSlot.teacher == slot.teacher,
      orElse: () => ExchangeOption(
        timeSlot: slot,
        teacherName: slot.teacher ?? '',
        type: ExchangeType.notExchangeable,
        priority: 999,
        reason: '교체 불가',
      ),
    );
    
    if (!option.isExchangeable) return null;
    
    // 교체 유형에 따른 아이콘
    IconData iconData;
    Color iconColor;
    
    switch (option.type) {
      case ExchangeType.sameClass:
        iconData = Icons.swap_horiz;
        iconColor = Colors.red.shade600;
        break;
      case ExchangeType.notExchangeable:
        return null;
    }
    
    return Positioned(
      top: 2,
      right: 2,
      child: Icon(
        iconData,
        color: iconColor,
        size: 12,
      ),
    );
  }
  
  
  /// 교체 가능한 시간의 텍스트 스타일
  static TextStyle getExchangeableTextStyle(TimeSlot slot, List<ExchangeOption> exchangeOptions) {
    ExchangeOption? option = exchangeOptions.firstWhere(
      (opt) => opt.timeSlot.dayOfWeek == slot.dayOfWeek && 
               opt.timeSlot.period == slot.period &&
               opt.timeSlot.teacher == slot.teacher,
      orElse: () => ExchangeOption(
        timeSlot: slot,
        teacherName: slot.teacher ?? '',
        type: ExchangeType.notExchangeable,
        priority: 999,
        reason: '교체 불가',
      ),
    );
    
    if (!option.isExchangeable) {
      return const TextStyle(
        fontSize: AppConstants.dataFontSize,
        fontWeight: FontWeight.normal,
        color: Colors.black,
      );
    }
    
    // 교체 가능한 시간은 굵은 글씨로 표시
    return TextStyle(
      fontSize: AppConstants.dataFontSize,
      fontWeight: FontWeight.bold,
      color: Colors.red.shade700,
    );
  }
  
  /// 교체 가능한 시간의 툴팁 텍스트
  static String getExchangeableTooltip(TimeSlot slot, List<ExchangeOption> exchangeOptions) {
    ExchangeOption? option = exchangeOptions.firstWhere(
      (opt) => opt.timeSlot.dayOfWeek == slot.dayOfWeek && 
               opt.timeSlot.period == slot.period &&
               opt.timeSlot.teacher == slot.teacher,
      orElse: () => ExchangeOption(
        timeSlot: slot,
        teacherName: slot.teacher ?? '',
        type: ExchangeType.notExchangeable,
        priority: 999,
        reason: '교체 불가',
      ),
    );
    
    if (!option.isExchangeable) {
      return slot.displayText;
    }
    
    return '${slot.displayText}\n\n교체 가능: ${option.reason}';
  }
  
  /// 교체 가능한 시간의 개수 표시
  static Widget buildExchangeableCountWidget(int count) {
    if (count == 0) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.swap_horiz,
            color: Colors.red.shade600,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            '교체 가능: $count개',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade700,
            ),
          ),
        ],
      ),
    );
  }
  
  
  
  
}
