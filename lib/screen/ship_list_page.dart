import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/main_area_dropdown.dart';
import '../components/sub_area_filter_chips.dart';
import '../components/date_selector.dart';
import '../components/filter_action_buttons.dart';
import '../components/ship_list_section.dart';
import '../components/chat_input_widget.dart';
import '../model/ship.dart';
import '../provider/ship_provider.dart';

class ShipListPage extends ConsumerStatefulWidget {
  const ShipListPage({super.key});

  @override
  ConsumerState<ShipListPage> createState() => _ShipListPageState();
}

class _ShipListPageState extends ConsumerState<ShipListPage> {
  DateTime selectedDate = DateTime.now();
  String? _selectedMainArea;
  List<String> _mainAreaOptions = [];
  List<String> _subAreaOptions = [];
  Set<String> _selectedSubAreas = {};
  bool _allSelected = true;

  @override
  void initState() {
    super.initState();
    _loadMainAreas();
  }

  Future<void> _loadMainAreas() async {
    final notifier = ref.read(shipListProvider.notifier);
    final areas = await notifier.getAllMainAreas();
    setState(() {
      _mainAreaOptions = areas;
    });
  }

  Future<void> _loadSubAreas(String mainArea) async {
    final notifier = ref.read(shipListProvider.notifier);
    final subAreas = await notifier.getSubAreasForMain(mainArea);
    setState(() {
      _selectedMainArea = mainArea;
      _subAreaOptions = subAreas.where((e) => e.isNotEmpty && e != '전체').toList();
      _selectedSubAreas = _subAreaOptions.toSet();
      _allSelected = true;
    });
    notifier.reset();
  }

  void _toggleAllSubAreas(bool selectAll) {
    setState(() {
      if (selectAll) {
        _selectedSubAreas = _subAreaOptions.toSet();
      } else {
        _selectedSubAreas.clear();
      }
      _allSelected = selectAll;
    });
  }

  void _toggleSubArea(String area, bool selected) {
    setState(() {
      if (selected) {
        _selectedSubAreas.add(area);
      } else {
        _selectedSubAreas.remove(area);
      }
      _allSelected = _selectedSubAreas.length == _subAreaOptions.length;
    });
  }

  void _resetState() {
    final notifier = ref.read(shipListProvider.notifier);
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
            MainAreaDropdown(
              selected: _selectedMainArea,
              options: _mainAreaOptions,
              onSelected: (area) async => await _loadSubAreas(area),
            ),
            const SizedBox(height: 8),
            if (_selectedMainArea != null && _subAreaOptions.isNotEmpty) ...[
              const SizedBox(height: 8),
              SubAreaFilterChips(
                subAreas: _subAreaOptions,
                selected: _selectedSubAreas,
                allSelected: _allSelected,
                onSelectAll: _toggleAllSubAreas,
                onToggle: _toggleSubArea,
              ),
              const SizedBox(height: 12),
              FilterActionButtons(
                onApply: () async {
                  FocusScope.of(context).unfocus();
                  notifier.setShipList([]);
                  ref.read(shipListProvider.notifier).state =
                      state.copyWith(ships: [], isLoading: true);

                  final allShips = <Ship>[];
                  for (final area in _selectedSubAreas) {
                    final ships = await notifier.fetchOnlyDirectWithMain(area, _selectedMainArea!);
                    allShips.addAll(ships);
                  }
                  notifier.setShipList(allShips);
                },
                onReset: _resetState,
              ),
            ],
            const SizedBox(height: 12),
            DateSelector(
              selectedDate: selectedDate,
              onPickDate: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) {
                  setState(() => selectedDate = picked);
                }
              },
            ),
            const SizedBox(height: 12),
            ShipListSection(
              state: state,
              selectedDate: selectedDate,
            ),
            const SizedBox(height: 12),
            const ChatInputWidget(),
          ],
        ),
      ),
    );
  }
}
