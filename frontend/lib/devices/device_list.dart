import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../model/device.dart';
import '../model/device_type.dart';
import '../navigation.dart';
import '../theme/dimens.dart';
import '../utils/friendly_date_formatter.dart';
import '../utils/oott_api.dart';
import '../utils/paginated_list_state.dart';
import '../widgets/empty_state.dart';
import '../widgets/filter_selector.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/skeleton.dart';
import 'device_list_filter.dart';
import 'device_list_rows.dart';
import 'device_list_sort.dart';
import '../routes.dart';

class DeviceList extends StatefulWidget {
  const DeviceList({super.key});

  @override
  State<DeviceList> createState() => _DeviceListState();
}

class _DeviceListState extends State<DeviceList>
    with RouteAware, PaginatedListState<DeviceList> {
  DeviceFilter _filter = DeviceFilter.newDevices;
  List<Device> _devices = [];
  final TextEditingController _ownerController = TextEditingController();
  DeviceType? _typeFilter;
  Timer? _ownerDebounce;

  DeviceSortColumn _sortColumn = DeviceSortColumn.lastSeen;
  bool _sortAscending = false;

  // Phones show fewer devices so the list and its pagination controls fit on
  // screen at once on the common current phones (e.g. iPhone 15, Pixel 8); the
  // wider table layout has the vertical room for a full page.
  @override
  int get phonePageSize => 5;
  @override
  int get widePageSize => 10;
  @override
  bool get isListEmpty => _devices.isEmpty;

  @override
  void initState() {
    super.initState();
    isLoading = true;
    _ownerController.addListener(_onOwnerChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is ModalRoute<void>) {
      routeObserver.subscribe(this, route);
    }
    // Deferred from initState so the page size can read the screen width from
    // MediaQuery, which is only available once dependencies are in place.
    if (!didInitialFetch) {
      didInitialFetch = true;
      _fetchPage(0);
    }
  }

  @override
  void didPopNext() {
    _fetchPage(currentPage);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _ownerDebounce?.cancel();
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

  /// Fetches [page]. When [scrollToTop] is set, the list animates back to its
  /// first row, so changing pages always starts the new page from the top.
  /// When [paging] is set the current page stays visible and the pagination
  /// bar shows a progress cue; background refreshes leave [paging] false so
  /// they don't flash the bar.
  Future<void> _fetchPage(
    int page, {
    bool scrollToTop = false,
    bool paging = false,
  }) {
    bool? isRegistered;
    if (_filter == DeviceFilter.newDevices) isRegistered = false;
    if (_filter == DeviceFilter.registered) isRegistered = true;
    return runFetch(
      page,
      scrollToTop: scrollToTop,
      paging: paging,
      fetch: (page, perPage, token) => BackendAPI.instance.listDevices(
        isRegistered: isRegistered,
        owner: _ownerController.text.isEmpty ? null : _ownerController.text,
        deviceType: _typeFilter,
        sortBy: _sortColumn.apiName,
        sortAscending: _sortAscending,
        page: page,
        perPage: perPage,
        cancelToken: token,
      ),
      onResult: (result) {
        setState(() {
          currentPage = page;
          totalCount = result.totalCount;
          _devices = result.items;
          isLoading = false;
          isPaging = false;
        });
      },
    );
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
                  child: FilterSelector<DeviceFilter>(
                    values: DeviceFilter.values,
                    selected: _filter,
                    labelOf: (f) => f.label,
                    onSelected: (f) {
                      setState(() => _filter = f);
                      _fetchPage(0);
                    },
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
    if (isLoading) {
      return const ListSkeleton();
    }
    if (error != null) {
      return Center(
        child: Text(
          'Error: $error',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    }
    if (_devices.isEmpty) {
      return EmptyState(
        icon: Icons.devices_other_outlined,
        message: _emptyMessage(),
        actionLabel: 'Check scanner status',
        onAction: () => context.go(Routes.status),
      );
    }

    final formatter = FriendlyDateFormatter();
    return RefreshIndicator(
      onRefresh: () => _fetchPage(currentPage),
      child: CustomScrollView(
        controller: scrollController,
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
                      onRefresh: () => _fetchPage(currentPage),
                    )
                  : DeviceRowCompact(
                      key: ValueKey(device.macAddress),
                      device: device,
                      formatter: formatter,
                      onRefresh: () => _fetchPage(currentPage),
                    );
            },
            separatorBuilder: (_, _) =>
                isWide ? const Divider(height: 1) : const SizedBox.shrink(),
          ),
          if (currentPage > 0 || totalPages > 1)
            SliverToBoxAdapter(
              child: PaginationBar(
                currentPage: currentPage,
                totalPages: totalPages,
                isLoading: isPaging,
                onPageChanged: (page) =>
                    _fetchPage(page, scrollToTop: true, paging: true),
              ),
            ),
        ],
      ),
    );
  }
}
