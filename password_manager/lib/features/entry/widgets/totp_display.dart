import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/totp/totp_service.dart';

/// A widget that displays a live TOTP code with a countdown timer.
/// Auto-updates every second via a periodic timer.
class TotpDisplay extends StatefulWidget {
  final String secret;
  final double codeFontSize;
  final bool compact;

  const TotpDisplay({
    super.key,
    required this.secret,
    this.codeFontSize = 28,
    this.compact = false,
  });

  @override
  State<TotpDisplay> createState() => _TotpDisplayState();
}

class _TotpDisplayState extends State<TotpDisplay> {
  String _code = '------';
  int _remaining = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _updateCode();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateCode());
  }

  @override
  void didUpdateWidget(TotpDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.secret != widget.secret) {
      _updateCode();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateCode() {
    if (!mounted) return;
    setState(() {
      _code = TotpService.generateCode(widget.secret);
      _remaining = TotpService.getRemainingSeconds();
    });
  }

  Color _timerColor() {
    if (_remaining > 10) return Colors.green;
    if (_remaining > 5) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _code,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 4),
          _buildTimerDot(),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.primaryContainer, width: 1),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Two-Factor Authentication Code',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _code,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: widget.codeFontSize,
              fontWeight: FontWeight.bold,
              letterSpacing: 6,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildTimerBar(),
              const SizedBox(width: 8),
              Text(
                '${_remaining}s',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _timerColor(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimerDot() {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(shape: BoxShape.circle, color: _timerColor()),
    );
  }

  Widget _buildTimerBar() {
    final fraction = _remaining / 30.0;
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: 120,
      height: 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(
          value: fraction,
          backgroundColor: colors.surfaceContainerHighest,
          valueColor: AlwaysStoppedAnimation(_timerColor()),
        ),
      ),
    );
  }
}
