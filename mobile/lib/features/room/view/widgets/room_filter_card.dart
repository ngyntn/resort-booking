import 'package:flutter/material.dart';
import 'package:mobile/features/room/models/room_model.dart';

class RoomFilterCard extends StatefulWidget {
  const RoomFilterCard({
    super.key,
    required this.initialFilters,
    required this.roomTypes,
    required this.onApply,
    required this.onClear,
  });

  final GetRoomsRequest initialFilters;
  final List<RoomTypeModel> roomTypes;
  final ValueChanged<GetRoomsRequest> onApply;
  final VoidCallback onClear;

  @override
  State<RoomFilterCard> createState() => _RoomFilterCardState();
}

class _RoomFilterCardState extends State<RoomFilterCard> {
  late TextEditingController _keywordController;
  late TextEditingController _maxPeopleController;
  late TextEditingController _minPriceController;
  late TextEditingController _maxPriceController;

  String? _selectedTypeId;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _keywordController = TextEditingController(
      text: widget.initialFilters.keyword ?? '',
    );
    _maxPeopleController = TextEditingController(
      text: widget.initialFilters.maxPeople?.toString() ?? '',
    );
    _minPriceController = TextEditingController(
      text: widget.initialFilters.priceRange?.minPrice ?? '',
    );
    _maxPriceController = TextEditingController(
      text: widget.initialFilters.priceRange?.maxPrice ?? '',
    );

    _selectedTypeId = widget.initialFilters.typeId?.toString();
    if (widget.initialFilters.dateRange?.startDate.isNotEmpty ?? false) {
      _startDate = DateTime.tryParse(
        widget.initialFilters.dateRange!.startDate,
      );
    }
    if (widget.initialFilters.dateRange?.endDate.isNotEmpty ?? false) {
      _endDate = DateTime.tryParse(widget.initialFilters.dateRange!.endDate);
    }
  }

  @override
  void didUpdateWidget(covariant RoomFilterCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialFilters != widget.initialFilters) {
      _keywordController.text = widget.initialFilters.keyword ?? '';
      _maxPeopleController.text =
          widget.initialFilters.maxPeople?.toString() ?? '';
      _minPriceController.text =
          widget.initialFilters.priceRange?.minPrice ?? '';
      _maxPriceController.text =
          widget.initialFilters.priceRange?.maxPrice ?? '';
      _selectedTypeId = widget.initialFilters.typeId?.toString();
      _startDate = widget.initialFilters.dateRange?.startDate.isNotEmpty == true
          ? DateTime.tryParse(widget.initialFilters.dateRange!.startDate)
          : null;
      _endDate = widget.initialFilters.dateRange?.endDate.isNotEmpty == true
          ? DateTime.tryParse(widget.initialFilters.dateRange!.endDate)
          : null;
    }
  }

  @override
  void dispose() {
    _keywordController.dispose();
    _maxPeopleController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isStartDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          (isStartDate ? _startDate : _endDate) ??
          DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );

    if (!mounted || picked == null) {
      return;
    }

    setState(() {
      if (isStartDate) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  GetRoomsRequest _buildRequest() {
    final selectedTypeId = _selectedTypeId == null || _selectedTypeId!.isEmpty
        ? null
        : int.tryParse(_selectedTypeId!);

    final minPrice = _minPriceController.text.trim();
    final maxPrice = _maxPriceController.text.trim();

    return GetRoomsRequest(
      page: 1,
      limit: widget.initialFilters.limit,
      keyword: _keywordController.text.trim().isEmpty
          ? null
          : _keywordController.text.trim(),
      typeId: selectedTypeId,
      maxPeople: _maxPeopleController.text.trim().isEmpty
          ? null
          : int.tryParse(_maxPeopleController.text.trim()),
      priceRange: (minPrice.isEmpty && maxPrice.isEmpty)
          ? null
          : PriceRangeQuery(
              minPrice: minPrice.isEmpty ? '0' : minPrice,
              maxPrice: maxPrice.isEmpty ? '999999' : maxPrice,
            ),
      dateRange: (_startDate == null && _endDate == null)
          ? null
          : DateRangeQuery(
              startDate: _startDate == null
                  ? ''
                  : _startDate!.toIso8601String().split('T').first,
              endDate: _endDate == null
                  ? ''
                  : _endDate!.toIso8601String().split('T').first,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filter Rooms',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Icon(Icons.filter_list),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Refine your stay with room type, guests, budget, and dates.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _keywordController,
              decoration: InputDecoration(
                labelText: 'Keyword',
                hintText: 'Room number or ID',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _selectedTypeId,
              decoration: InputDecoration(
                labelText: 'Room Type',
                prefixIcon: const Icon(Icons.category),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              hint: const Text('Select a room type'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All types'),
                ),
                ...widget.roomTypes.map(
                  (roomType) => DropdownMenuItem<String?>(
                    value: roomType.id.toString(),
                    child: Text(roomType.name),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() => _selectedTypeId = value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _maxPeopleController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Number of Guests',
                prefixIcon: const Icon(Icons.people),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minPriceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Min Price',
                      prefixIcon: const Icon(Icons.attach_money),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _maxPriceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Max Price',
                      prefixIcon: const Icon(Icons.attach_money),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _pickDate(true),
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Check-in',
                        prefixIcon: const Icon(Icons.calendar_today),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _startDate == null
                            ? 'Select check-in'
                            : _startDate!.toIso8601String().split('T').first,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => _pickDate(false),
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Check-out',
                        prefixIcon: const Icon(Icons.calendar_today),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _endDate == null
                            ? 'Select check-out'
                            : _endDate!.toIso8601String().split('T').first,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _clearFields();
                      widget.onClear();
                    },
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => widget.onApply(_buildRequest()),
                    icon: const Icon(Icons.search),
                    label: const Text('Apply'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _clearFields() {
    setState(() {
      _keywordController.clear();
      _maxPeopleController.clear();
      _minPriceController.clear();
      _maxPriceController.clear();
      _selectedTypeId = null;
      _startDate = null;
      _endDate = null;
    });
  }
}
