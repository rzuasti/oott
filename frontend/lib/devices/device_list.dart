import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../model/device.dart';
import '../model/device_type.dart';
import '../navigation.dart';
import '../utils/friendly_date_formatter.dart';
import '../utils/oott_api.dart';
import 'device_list_filter.dart';
import 'device_list_rows.dart';
import 'device_list_sort.dart';

const _pageSize = 10;
const _wideLayoutBreakpoint = 600.0;

class DeviceList extends StatefulWidget {
  const DeviceList({super.key});

  @override
  State<DeviceList> createState() => _DeviceListState();
}

class _DeviceListState extends State<DeviceList> with RouteAware {
  DeviceFilter _filter = DeviceFilter.newDevices;
  List<Device> _devices = [];
  bool _isLoading = true;
  String? _error;
  final TextEditingController _ownerController = TextEditingController();
  DeviceType? _typeFilter;
  Timer? _ownerDebounce;

  DeviceSortColumn _sortColumn = DeviceSortColumn.lastSeen;
  bool _sortAscending = false;

  int _currentPage = 0;
  bool _hasNextPage = false;
  CancelToken? _fetchToken;

  @override
  void initState() {
    super.initState();
    _ownerController.addListener(_onOwnerChanged);
    _fetchPage(0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is ModalRoute<void>) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void didPopNext() {
    _fetchPage(_currentPage);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _ownerDebounce?.cancel();
    _fetchToken?.cancel();
    _ownerController.dispose();
    super.dispose();
  }

  void _onOwnerChanged() {
    _ownerDebounce?.cancel();
    _ownerDebounce = Timer(
      const Duration(milliseconds: 500),
      () => _fetchPage(0),
    );
  }

  Future<void> _fetchPage(int page) async {
    _fetchToken?.cancel();
    final token = CancelToken();
    _fetchToken = token;
    setState(() {
      _isLoading = _devices.isEmpty;
      _error = null;
    });
    try {
      bool? isRegistered;
      if (_filter == DeviceFilter.newDevices) isRegistered = false;
      if (_filter == DeviceFilter.registered) isRegistered = true;

      final results = await BackendAPI.instance.listDevices(
        isRegistered: isRegistered,
        owner: _ownerController.text.isEmpty ? null : _ownerController.text,
        deviceType: _typeFilter,
        sortBy: _sortColumn.apiName,
        sortAscending: _sortAscending,
        offset: page * _pageSize,
        limit: _pageSize + 1,
        cancelToken: token,
      );
      if (!mounted || token != _fetchToken) return;
      setState(() {
        _currentPage = page;
        _hasNextPage = results.length > _pageSize;
        _devices = _hasNextPage ? results.take(_pageSize).toList() : results;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || token != _fetchToken) return;
      if (e is DioException && e.type == DioExceptionType.cancel) return;
      setState(() {
        _error = dioErrorToUserMessage(e);
        _isLoading = false;
      });
    }
  }

  void _onSortHeaderTapped(DeviceSortColumn column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = true;
      }
    });
    _fetchPage(0);
  }

  void _onSortSheetChanged(DeviceSortColumn column, bool ascending) {
    if (_sortColumn == column && _sortAscending == ascending) return;
    setState(() {
      _sortColumn = column;
      _sortAscending = ascending;
    });
    _fetchPage(0);
  }

  String _emptyMessage() => switch (_filter) {
    DeviceFilter.newDevices => 'No unregistered devices',
    DeviceFilter.registered => 'No registered devices',
    DeviceFilter.all => 'No devices found',
  };

  bool get _hasActiveDetailFilters =>
      _ownerController.text.isNotEmpty || _typeFilter != null;

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DeviceFilterSheet(
        ownerController: _ownerController,
        typeFilter: _typeFilter,
        hasActiveFilters: _hasActiveDetailFilters,
        onTypeChanged: (value) {
          setState(() => _typeFilter = value);
          _fetchPage(0);
        },
        onClear: () {
          setState(() {
            _ownerController.clear();
            _typeFilter = null;
          });
          _fetchPage(0);
        },
      ),
    );
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DeviceSortSheet(
        currentColumn: _sortColumn,
        ascending: _sortAscending,
        onChanged: _onSortSheetChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _wideLayoutBreakpoint;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Devices', style: textTheme.headlineSmall),
                ),
                if (!isWide)
                  IconButton(
                    icon: const Icon(Icons.sort),
                    tooltip: 'Sort',
                    onPressed: _showSortSheet,
                  ),
                Badge(
                  isLabelVisible: _hasActiveDetailFilters,
                  child: IconButton(
                    icon: const Icon(Icons.filter_list),
                    tooltip: 'Filter',
                    onPressed: _showFilterSheet,
                  ),
                ),
              ],
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Wrap(
                spacing: 8.0,
                children: DeviceFilter.values
                    .map(
                      (f) => ChoiceChip(
                        label: Text(f.label),
                        selected: _filter == f,
                        onSelected: (_) {
                          setState(() => _filter = f);
                          _fetchPage(0);
                        },
                      ),
                    )
                    .toList(),
              ),
            ),
            Expanded(child: _buildBody(context, isWide)),
          ],
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, bool isWide) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Text(
          'Error: $_error',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    }
    if (_devices.isEmpty) {
      final theme = Theme.of(context);
      return Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 12),
        child: Center(
          child: Text(
            _emptyMessage(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final formatter = FriendlyDateFormatter();
    return RefreshIndicator(
      onRefresh: () => _fetchPage(_currentPage),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (isWide)
            SliverPersistentHeader(
              pinned: true,
              delegate: DeviceListHeaderDelegate(
                sortColumn: _sortColumn,
                ascending: _sortAscending,
                onTap: _onSortHeaderTapped,
              ),
            ),
          SliverList.separated(
            itemCount: _devices.length,
            itemBuilder: (context, index) {
              final device = _devices[index];
              return isWide
                  ? DeviceRowWide(
                      key: ValueKey(device.macAddress),
                      device: device,
                      formatter: formatter,
                      onRefresh: () => _fetchPage(_currentPage),
                    )
                  : DeviceRowCompact(
                      key: ValueKey(device.macAddress),
                      device: device,
                      formatter: formatter,
                      onRefresh: () => _fetchPage(_currentPage),
                    );
            },
            separatorBuilder: (_, _) => const Divider(height: 1),
          ),
          if (_currentPage > 0 || _hasNextPage) _buildPaginationControls(),
        ],
      ),
    );
  }

  Widget _buildPaginationControls() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton.outlined(
              onPressed: _currentPage > 0 && !_isLoading
                  ? () => _fetchPage(0)
                  : null,
              icon: const Icon(Icons.first_page),
              tooltip: 'First page',
            ),
            const SizedBox(width: 8),
            IconButton.outlined(
              onPressed: _currentPage > 0 && !_isLoading
                  ? () => _fetchPage(_currentPage - 1)
                  : null,
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Previous page',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Page ${_currentPage + 1}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            IconButton.outlined(
              onPressed: _hasNextPage && !_isLoading
                  ? () => _fetchPage(_currentPage + 1)
                  : null,
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Next page',
            ),
          ],
        ),
      ),
    );
  }
}
