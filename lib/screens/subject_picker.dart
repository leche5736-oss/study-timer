import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';

/// 과목 고르기 시트. 고른 과목 id를, 닫으면 null을 돌려줍니다.
/// [markId] 과목 옆에는 [markLabel]을 작게 표시합니다 (지난번, 지금 등).
Future<String?> pickSubject(
  BuildContext context,
  List<Subject> subjects, {
  String title = '무엇을 공부할까요?',
  String? markId,
  String markLabel = '지난번',
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  builder: (c) => SafeArea(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(c).height * 0.7),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              title,
              style: const TextStyle(color: AppColors.grey, fontSize: 15),
            ),
          ),
          for (final s in subjects)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: CircleAvatar(radius: 7, backgroundColor: s.colorValue),
              minLeadingWidth: 14,
              title: Text(s.name, style: const TextStyle(fontSize: 17)),
              trailing: s.id == markId
                  ? Text(
                      markLabel,
                      style: const TextStyle(
                        color: AppColors.grey,
                        fontSize: 13,
                      ),
                    )
                  : null,
              onTap: () => Navigator.pop(c, s.id),
            ),
        ],
      ),
    ),
  ),
);
