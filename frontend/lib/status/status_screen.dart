import 'dart:async';

import 'package:flutter/material.dart';
import 'package:frontend/model/arp_scanner_status.dart';
import 'package:frontend/utils/oott_api.dart';
import 'package:frontend/widgets/arp_scanner_card.dart';

class StatusScreen extends StatefulWidget {
  const StatusScreen({super.key});

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  ArpScannerStatus? _status;
  DateTime? _statusReceivedAt;
  bool _isLoading = true;
  String? _error;
  Timer? _refreshTimer;
  Timer? _tickTimer;

  @override
  void initState() {
    super.initState();
    _loadStatus();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _loadStatus(),
    );
    _tickTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tickTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    try {
      final status = await BackendAPI.instance.getArpScannerStatus();
      if (!mounted) return;
      setState(() {
        _status = status;
        _statusReceivedAt = DateTime.now();
        _error = null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Status', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 20),
        ArpScannerCard(
          status: _status,
          statusReceivedAt: _statusReceivedAt,
          error: _error,
          isLoading: _isLoading,
        ),
      ],
    );
  }
}
