import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../state/ship_list_state.dart';

class ShipListSection extends StatelessWidget {
  final ShipListState state;
  final DateTime selectedDate;

  const ShipListSection({
    super.key,
    required this.state,
    required this.selectedDate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('${state.ships.length}척의 예약가능한 선박이 검색됨',
                style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 8),
            Icon(
              state.isLoading ? Icons.circle : Icons.check_circle,
              color: state.isLoading ? Colors.red : Colors.green,
              size: 16,
            ),
          ],
        ),
        const SizedBox(height: 12),
        state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : state.ships.isEmpty
                ? const Text('결과 없음')
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: state.ships.length,
                    itemBuilder: (_, i) {
                      final s = state.ships[i];
                      final sdate =
                          "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";
                      final url =
                          'https://www.sunsang24.com/ship/list/?ship_no=${s.shipNo}&sdate=$sdate';

                      return Card(
                        child: ListTile(
                          title: Text(
                              '${i + 1}. ${s.name} (${s.areaMain} ${s.areaSub})'),
                          subtitle: Text('${s.fishType} / 남은자리: ${s.remain}'),
                          onTap: () async {
                            final uri = Uri.parse(url);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri,
                                  mode: LaunchMode.externalApplication);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('브라우저를 열 수 없습니다.')),
                              );
                            }
                          },
                        ),
                      );
                    },
                  ),
      ],
    );
  }
}
