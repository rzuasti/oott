import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../model/device.dart';
import '../model/device_type.dart';
import '../navigation.dart';
import '../theme/dimens.dart';
import '../utils/friendly_date_formatter.dart';
import '../utils/oott_api.dart';
import '../widgets/empty_state.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/skeleton.dart';
import 'device_list_filter.dart';
import 'device_list_rows.dart';
import 'device_list_sort.dart';

const _pageSize = 10;

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

      final result = await BackendAPI.instance.listDevices(
        isRegistered: isRegistered,
        owner: _ownerController.text.isEmpty ? null : _ownerController.text,
        deviceType: _typeFilter,
        sortBy: _sortColumn.apiName,
        sortAscending: _sortAscending,
        page: page,
        perPage: _pageSize,
        cancelToken: token,
      );
      if (!mounted || token != _fetchToken) return;
      setState(() {
        _currentPage = page;
        _hasNextPage = result.hasNextPage;
        _devices = result.items;
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

  /// Presents [child] as a modal bottom sheet on narrow (phone) layouts and as
  /// a centered dialog on wider (tablet/desktop) layouts, where a sheet sliding
  /// up from the bottom of a large window reads poorly.
  Future<void> _showAdaptivePanel(Widget child) {
    final isWide = MediaQuery.sizeOf(context).width >= Breakpoints.medium;
    if (isWide) {
      return showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(child: child),
          ),
        ),
      );
    }
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => child,
    );
  }

  void _showFilterSheet() {
    _showAdaptivePanel(
      DeviceFilterSheet(
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
    _showAdaptivePanel(
      DeviceSortSheet(
        currentColumn: _sortColumn,
        ascending: _sortAscending,
        onChanged: _onSortSheetChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= Breakpoints.medium;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: Insets.sm,
                      vertical: Insets.xs,
                    ),
                    child: Wrap(
                      spacing: Insets.sm,
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
            Expanded(child: _buildBody(context, isWide)),
          ],
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, bool isWide) {
    if (_isLoading) {
      return const ListSkeleton();
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
      return EmptyState(
        icon: Icons.devices_other_outlined,
        message: _emptyMessage(),
        actionLabel: 'Check scanner status',
        onAction: () => context.go('/status'),
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
          if (_currentPage > 0 || _hasNextPage)
            SliverToBoxAdapter(
              child: PaginationBar(
                currentPage: _currentPage,
                hasNextPage: _hasNextPage,
                isLoading: _isLoading,
                onPageChanged: _fetchPage,
              ),
            ),
        ],
      ),
    );
  }
}
