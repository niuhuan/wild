import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wild/pages/update_cubit.dart';

class UpdateChecker extends StatefulWidget {
  final Widget child;
  final bool forceCheck;

  const UpdateChecker({
    super.key,
    required this.child,
    this.forceCheck = false,
  });

  @override
  State<UpdateChecker> createState() => _UpdateCheckerState();
}

class _UpdateCheckerState extends State<UpdateChecker> {
  OverlayEntry? _overlayEntry;

  @override
  void dispose() {
    _overlayEntry?.remove();
    super.dispose();
  }

  void _showUpdateDialog(VersionInfo updateInfo) {
    _overlayEntry?.remove();
    _overlayEntry = OverlayEntry(
      builder: (context) => Material(
        color: Colors.black54,
        child: Center(
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '发现新版本',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '最新版本：${updateInfo.version}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    updateInfo.body,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        _overlayEntry?.remove();
                        _overlayEntry = null;
                      },
                      child: const Text('我知道了'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  Future<void> _checkUpdate() async {
    final updateInfo = await context.read<UpdateCubit>().checkUpdate(force: widget.forceCheck);
    if (updateInfo != null && mounted) {
      _showUpdateDialog(updateInfo);
    }
  }

  @override
  void initState() {
    super.initState();
    // 在下一帧检查更新，确保 context 已经准备好
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUpdate();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
} 