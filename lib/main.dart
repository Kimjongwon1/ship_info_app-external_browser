import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'model/ship.dart';
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
  String? _regionMainTitle;
  bool _isMainRegion = false;

  List<String> _subAreaOptions = [];
  Set<String> _selectedSubAreas = {};
  bool _allSelected = true;

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
                            _subAreaOptions.clear();
                            _selectedSubAreas.clear();
                          });
                        },
                      )
                    : null,
              ),
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

                      final inputNorm = regionController.text
                          .toLowerCase()
                          .replaceAll(' ', '');
                      final mainNorm =
                          (mainTitle ?? '').toLowerCase().replaceAll(' ', '');

                      if (inputNorm == mainNorm) {
                        final subAreas = (await notifier
                                .getSubAreasForMain(regionController.text))
                            .where((s) => s != '전체')
                            .toList();
                        setState(() {
                          _subAreaOptions = subAreas;
                          _selectedSubAreas = subAreas.toSet();
                          _allSelected = true;
                        });
                      } else {
                        setState(() {
                          _subAreaOptions.clear();
                          _selectedSubAreas.clear();
                          _allSelected = false;
                        });
                      }

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
                if (_isRegionSearched && !_isMainRegion)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        FocusScope.of(context).unfocus();
                        final (mainTitle, _) = await notifier
                            .fetchAllBySubArea(regionController.text);
                        setState(() {
                          _regionMainTitle = mainTitle;
                        });
                      },
                      child: Text(
                        _regionMainTitle != null
                            ? '${_regionMainTitle!} 전체'
                            : '전체',
                      ),
                    ),
                  ),
              ],
            ),
            if (_isMainRegion && _subAreaOptions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (_subAreaOptions.length > 1)
                    FilterChip(
                      label: const Text('하위 전체 선택'),
                      selected: _allSelected,
                      onSelected: (_) {
                        setState(() {
                          if (_allSelected) {
                            _selectedSubAreas.clear();
                            _allSelected = false;
                          } else {
                            _selectedSubAreas = _subAreaOptions.toSet();
                            _allSelected = true;
                          }
                        });
                      },
                    ),
                  ..._subAreaOptions.map((area) {
                    final isSelected = _selectedSubAreas.contains(area);
                    return FilterChip(
                      label: Text(area),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedSubAreas.add(area);
                          } else {
                            _selectedSubAreas.remove(area);
                          }
                          _allSelected = _selectedSubAreas.length ==
                              _subAreaOptions.length;
                        });
                      },
                    );
                  }),
                ],
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () async {
                  FocusScope.of(context).unfocus();
                  final allShips = <Ship>[];
                  for (final area in _selectedSubAreas) {
                    final ships = await notifier.fetchOnlyDirect(area);
                    allShips.addAll(ships);
                  }
                  setState(() {
                    ref.read(shipListProvider.notifier).setShipList(allShips);
                  });
                },
                child: const Text('필터 적용'),
              ),
            ],
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
