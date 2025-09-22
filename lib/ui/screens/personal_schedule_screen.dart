import 'package:flutter/material.dart';

/// 개인 시간표 화면
class PersonalScheduleScreen extends StatelessWidget {
  const PersonalScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person,
            size: 64,
            color: Colors.blue,
          ),
          SizedBox(height: 16),
          Text(
            '개인 시간표',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '개인 시간표를 보여주는 화면입니다.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

