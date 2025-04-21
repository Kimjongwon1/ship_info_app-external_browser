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
  @override
  void initState() {
    super.initState();
    _loadMainAreas();
  }

  DateTime selectedDate = DateTime.now();

  String? _selectedMainArea;
  List<String> _mainAreaOptions = [];
  List<String> _subAreaOptions = [];
  Set<String> _selectedSubAreas = {};
  bool _allSelected = true;

  Future<void> _loadMainAreas() async {
    final notifier = ref.read(shipListProvider.notifier);
    final areas = await notifier.getAllMainAreas();
    setState(() {
      _mainAreaOptions = areas;
    });
  }

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

  Future<void> _loadSubAreas(String mainArea, WidgetRef ref) async {
    final notifier = ref.read(shipListProvider.notifier);
    final subAreas = await notifier.getSubAreasForMain(mainArea);
    setState(() {
      _selectedMainArea = mainArea;
      _subAreaOptions =
          subAreas.where((e) => e.isNotEmpty && e != '전체').toList();
      _selectedSubAreas = _subAreaOptions.toSet();
      _allSelected = true;
    });
    notifier.reset();
  }

  void _resetState(ShipListNotifier notifier) {
    notifier.reset();
    setState(() {
      _selectedMainArea = null;
      _mainAreaOptions.clear();
      _subAreaOptions.clear();
      _selectedSubAreas.clear();
      _allSelected = true;
    });
    _loadMainAreas();
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButton<String>(
              value: _selectedMainArea,
              hint: const Text('메인 지역 선택'),
              isExpanded: true,
              items: _mainAreaOptions.map((area) {
                return DropdownMenuItem<String>(
                  value: area,
                  child: Text(area),
                );
              }).toList(),
              onChanged: (area) async {
                if (area != null) {
                  await _loadSubAreas(area, ref);
                }
              },
            ),
            const SizedBox(height: 8),
            if (_selectedMainArea != null && _subAreaOptions.isNotEmpty) ...[
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('하위 지역 필터'),
                ],
              ),
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
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        FocusScope.of(context).unfocus();
                        notifier.setShipList([]);
                        ref.read(shipListProvider.notifier).state =
                            state.copyWith(ships: [], isLoading: true);

                        final allShips = <Ship>[];
                        for (final area in _selectedSubAreas) {
                          final ships = await notifier.fetchOnlyDirectWithMain(
                              area, _selectedMainArea!);
                          allShips.addAll(ships);
                        }
                        notifier.setShipList(allShips);
                      },
                      child: const Text('필터 적용'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _resetState(notifier),
                    child: const Text('초기화'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
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
            const SizedBox(height: 16),
            Expanded(
              child: Center(
                child: state.isLoading
                    ? const CircularProgressIndicator()
                    : state.ships.isEmpty
                        ? const Text('결과 없음')
                        : ListView.builder(
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
                                  subtitle:
                                      Text('${s.fishType} / 남은자리: ${s.remain}'),
                                  onTap: () async {
                                    final uri = Uri.parse(url);
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(uri,
                                          mode: LaunchMode.externalApplication);
                                    } else {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text('브라우저를 열 수 없습니다.')),
                                      );
                                    }
                                  },
                                ),
                              );
                            },
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
