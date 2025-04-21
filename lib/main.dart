import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'provider/ship_provider.dart';

void main() => runApp(
      const ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: ShipListPage(),
        ),
      ),
    );

class ShipListPage extends ConsumerStatefulWidget {
  const ShipListPage({super.key});

  @override
  ConsumerState<ShipListPage> createState() => _ShipListPageState();
}

class _ShipListPageState extends ConsumerState<ShipListPage> {
  final regionController = TextEditingController();
  DateTime selectedDate = DateTime.now();

  bool _isRegionSearched = false;
  String? _regionMainTitle; // ✅ 대지역 이름
  bool _isMainRegion = false; // ✅ 대지역 여부

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(shipListProvider);
    final notifier = ref.read(shipListProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('출조 정보 조회')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: regionController,
              decoration: InputDecoration(
                labelText: '지역 입력 (예: 여수)',
                suffixIcon: regionController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          regionController.clear();
                          notifier.reset();
                          setState(() {
                            _isRegionSearched = false;
                            _regionMainTitle = null;
                            _isMainRegion = false;
                          });
                        },
                      )
                    : null,
              ),
              onSubmitted: (_) {
                FocusScope.of(context).unfocus();
              },
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "선택된 날짜: ${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}",
                  style: const TextStyle(fontSize: 14),
                ),
                TextButton(
                  onPressed: _selectDate,
                  child: const Text("날짜 선택"),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      FocusScope.of(context).unfocus();
                      await notifier.fetchOnly(regionController.text);
                      final mainTitle = await notifier
                          .getAreaMainTitle(regionController.text);

                      // ✅ 입력과 메인타이틀이 같으면 대지역이다
                      final inputNorm = regionController.text
                          .toLowerCase()
                          .replaceAll(' ', '');
                      final mainNorm =
                          (mainTitle ?? '').toLowerCase().replaceAll(' ', '');

                      setState(() {
                        _isRegionSearched = true;
                        _regionMainTitle = mainTitle;
                        _isMainRegion = (inputNorm == mainNorm);
                      });
                    },
                    child: const Text('지역검색'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isRegionSearched && !_isMainRegion
                        ? () async {
                            FocusScope.of(context).unfocus();
                            final (mainTitle, _) = await notifier
                                .fetchAllBySubArea(regionController.text);
                            setState(() {
                              _regionMainTitle = mainTitle;
                            });
                          }
                        : null,
                    child: Text(
                      _regionMainTitle != null && !_isMainRegion
                          ? '${_regionMainTitle!} 전체'
                          : '전체',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('${state.ships.length}척의 예약가능한 선박이 검색됨',
                style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 16),
            if (state.isLoading)
              const CircularProgressIndicator()
            else if (state.ships.isEmpty)
              const Text('결과 없음')
            else
              Expanded(
                child: ListView.builder(
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
                              const SnackBar(content: Text('브라우저를 열 수 없습니다.')),
                            );
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
