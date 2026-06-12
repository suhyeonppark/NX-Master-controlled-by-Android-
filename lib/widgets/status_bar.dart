import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/device_status.dart';

class ConnectionDots extends StatelessWidget {
  const ConnectionDots({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => _showDetails(context, state),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: _Chip(label: 'NX', status: state.nxStatus),
      ),
    );
  }

  void _showDetails(BuildContext context, AppState state) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('연결 상태'),
        content: _DetailRow(label: 'AMX NX-2200', status: state.nxStatus),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('닫기'),
          ),
          FilledButton.icon(
            onPressed: state.isBusy
                ? null
                : () {
                    state.unawaitedTest();
                    Navigator.of(ctx).pop();
                  },
            icon: const Icon(Icons.refresh),
            label: const Text('새로고침'),
          ),
        ],
      ),
    );
  }
}

Color _statusColor(DeviceStatus status) {
  switch (status.state) {
    case DeviceConnectionState.online:
      return const Color(0xFF2E7D32);
    case DeviceConnectionState.offline:
      return const Color(0xFFC62828);
    case DeviceConnectionState.checking:
      return const Color(0xFFEF6C00);
    case DeviceConnectionState.unknown:
      return Colors.grey;
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.status});

  final DeviceStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: _statusColor(status), shape: BoxShape.circle),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.status});

  final String label;
  final DeviceStatus status;

  @override
  Widget build(BuildContext context) {
    final c = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Dot(status: status),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: c,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.status});

  final String label;
  final DeviceStatus status;

  @override
  Widget build(BuildContext context) {
    final c = _statusColor(status);
    return Row(
      children: [
        _Dot(status: status),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 16))),
        Text(
          status.label,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c),
        ),
      ],
    );
  }
}
