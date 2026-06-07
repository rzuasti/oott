import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../model/device.dart';
import '../model/device_event.dart';
import '../model/device_event_type.dart';
import '../utils/oott_api.dart';
import '../widgets/filter_selector.dart';
import '../theme/dimens.dart';

enum _TimeRange {
  today('Today'),
  lastWeek('Last week'),
  lastThreeMonths('Last 3 months'),
  lastSixMonths('Last 6 months'),
  lastYear('Last year');

  const _TimeRange(this.label);

  final String label;

  DateTime get cutoff {
    final now = DateTime.now();
    return switch (this) {
      _TimeRange.today => DateTime(now.year, now.month, now.day),
      _TimeRange.lastWeek => now.subtract(const Duration(days: 7)),
      _TimeRange.lastThreeMonths => now.subtract(const Duration(days: 90)),
      _TimeRange.lastSixMonths => now.subtract(const Duration(days: 180)),
      _TimeRange.lastYear => now.subtract(const Duration(days: 365)),
    };
  }

  double get xIntervalMs {
    const hour = 3600000.0;
    const day = 86400000.0;
    return switch (this) {
      _TimeRange.today => 4 * hour,
      _TimeRange.lastWeek => day,
      _TimeRange.lastThreeMonths => 14 * day,
      _TimeRange.lastSixMonths => 30 * day,
      _TimeRange.lastYear => 60 * day,
    };
  }

  String formatLabel(DateTime dt) {
    final isCurrentYear = dt.year == DateTime.now().year;
    return switch (this) {
      _TimeRange.today => DateFormat('HH:mm').format(dt),
      _TimeRange.lastWeek =>
        isCurrentYear
            ? DateFormat('EEE').format(dt)
            : DateFormat('EEE yyyy').format(dt),
      _TimeRange.lastThreeMonths || _TimeRange.lastSixMonths =>
        isCurrentYear
            ? DateFormat('MMM d').format(dt)
            : DateFormat('MMM d, yyyy').format(dt),
      _TimeRange.lastYear =>
        isCurrentYear
            ? DateFormat('MMM').format(dt)
            : DateFormat('MMM yyyy').format(dt),
    };
  }
}

class DeviceEventHistory extends StatefulWidget {
  final Device device;

  const DeviceEventHistory({super.key, required this.device});

  @override
  State<DeviceEventHistory> createState() => _DeviceEventHistoryState();
}

class _DeviceEventHistoryState extends State<DeviceEventHistory> {
  List<DeviceEvent>? _events;
  bool _isLoading = true;
  String? _error;
  _TimeRange _selectedRange = _TimeRange.lastWeek;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final events = await BackendAPI.instance.getDeviceEvents(
        widget.device.macAddress,
        createdFrom: _selectedRange.cutoff,
      );
      if (!mounted) return;
      setState(() {
        _events = events;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (e is DioException && e.type == DioExceptionType.cancel) return;
      setState(() {
        _error = dioErrorToUserMessage(e);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(Insets.xxxl),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Insets.lg),
        child: Center(child: Text('Failed to load event history: $_error')),
      );
    }

    final events = _events ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilterSelector<_TimeRange>(
          values: _TimeRange.values,
          selected: _selectedRange,
          labelOf: (r) => r.label,
          onSelected: (range) {
            setState(() => _selectedRange = range);
            _loadEvents();
          },
        ),
        const SizedBox(height: Insets.lg),
        if (events.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: Insets.xxl),
            child: Center(child: Text('No events in this time range')),
          )
        else
          SizedBox(
            height: 160,
            child: _EventChart(events: events, range: _selectedRange),
          ),
      ],
    );
  }
}

class _EventChart extends StatelessWidget {
  final List<DeviceEvent> events;
  final _TimeRange range;

  const _EventChart({required this.events, required this.range});

  // Marker radius and colour per event type. The type itself conveys what happened, so the chart
  // trusts it rather than comparing each event's snapshot against the device's current state.
  static ({double radius, Color color}) _markerStyle(
    DeviceEventType type,
    ColorScheme scheme,
  ) => switch (type) {
    DeviceEventType.newDevice => (radius: 9.0, color: scheme.tertiary),
    DeviceEventType.deviceSeen => (radius: 4.0, color: scheme.tertiary),
    DeviceEventType.deviceChanged => (radius: 7.0, color: scheme.error),
    DeviceEventType.deviceBackOnline => (radius: 7.0, color: scheme.primary),
  };

  // Human-readable label for an event type, shown in the tooltip.
  static String _eventLabel(DeviceEventType type) => switch (type) {
    DeviceEventType.newDevice => 'First seen',
    DeviceEventType.deviceSeen => 'Device seen',
    DeviceEventType.deviceChanged => 'Device changed',
    DeviceEventType.deviceBackOnline => 'Device back online',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final cutoff = range.cutoff;
    final intervalMs = range.xIntervalMs;
    final cutoffMs = cutoff.millisecondsSinceEpoch.toDouble();
    final nowMs = now.millisecondsSinceEpoch.toDouble();

    // Snap axis bounds to interval boundaries so every tick falls within the chart.
    // This may add a small margin on each side, which is intentional.
    final minX = (cutoffMs / intervalMs).floor() * intervalMs;
    final maxX = (nowMs / intervalMs).ceil() * intervalMs;

    final spots = events.map((e) {
      final style = _markerStyle(e.eventType, theme.colorScheme);
      return ScatterSpot(
        e.createdOn.millisecondsSinceEpoch.toDouble(),
        1.0,
        dotPainter: FlDotCirclePainter(
          radius: style.radius,
          color: style.color,
        ),
      );
    }).toList();

    return ScatterChart(
      ScatterChartData(
        scatterSpots: spots,
        minX: minX,
        maxX: maxX,
        minY: 0.0,
        maxY: 2.0,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawHorizontalLine: false,
          verticalInterval: range.xIntervalMs,
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: range.xIntervalMs,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final dt = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                return SideTitleWidget(
                  meta: meta,
                  fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                  child: Text(
                    range.formatLabel(dt),
                    style: theme.textTheme.labelSmall,
                  ),
                );
              },
            ),
          ),
        ),
        scatterTouchData: ScatterTouchData(
          touchTooltipData: ScatterTouchTooltipData(
            maxContentWidth: 260,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipColor: (_) => theme.colorScheme.surfaceContainerHighest,
            getTooltipItems: (ScatterSpot touchedSpot) {
              final idx = events.indexWhere(
                (e) =>
                    e.createdOn.millisecondsSinceEpoch.toDouble() ==
                    touchedSpot.x,
              );
              if (idx < 0) return null;

              final event = events[idx];
              final dt = event.createdOn.toLocal();
              final dateStr = DateFormat('MMM d, yyyy HH:mm').format(dt);
              final typeLabel =
                  '${_eventLabel(event.eventType)} (${event.scannerLabel})';

              return ScatterTooltipItem(
                '$dateStr\n$typeLabel',
                textStyle: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 12,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
