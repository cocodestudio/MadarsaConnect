import 'package:flutter/material.dart';

class CustomPopup {
  static void show(BuildContext context, String message) {
    OverlayEntry? entry;
    entry = OverlayEntry(
      builder:
          (context) => _PopupMessage(
            message: message,
            onDismissed: () {
              entry?.remove();
            },
          ),
    );

    Navigator.of(context, rootNavigator: true).overlay?.insert(entry);
  }
}

class _PopupMessage extends StatefulWidget {
  final String message;
  final VoidCallback onDismissed;

  const _PopupMessage({
    Key? key,
    required this.message,
    required this.onDismissed,
  }) : super(key: key);

  @override
  State<_PopupMessage> createState() => _PopupMessageState();
}

class _PopupMessageState extends State<_PopupMessage> {
  bool _isShowing = false;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _startAnimation();
  }

  void _startAnimation() async {
    if (!mounted) return;

    await Future.delayed(const Duration(milliseconds: 50));
    setState(() => _isShowing = true);

    await Future.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    setState(() => _isExpanded = true);

    await Future.delayed(const Duration(milliseconds: 2500));
    _dismiss();
  }

  void _dismiss() async {
    if (!mounted) return;
    setState(() => _isExpanded = false);

    await Future.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    setState(() => _isShowing = false);

    await Future.delayed(const Duration(milliseconds: 500));
    widget.onDismissed();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return AnimatedPositioned(
      top: _isShowing ? topPadding + 10 : -100,
      left: 0,
      right: 0,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutQuint,
      child: Align(
        alignment: Alignment.topCenter,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 450),
          curve: Curves.fastOutSlowIn,
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: 20,
            vertical: _isExpanded ? 12 : 0,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF252525),
            borderRadius: BorderRadius.circular(50),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: AnimatedOpacity(
            opacity: _isExpanded ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Material(
              color: Colors.transparent,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.message == "No Internet Connection" ||
                      widget.message == "Back Online") ...[
                    Icon(
                      widget.message == "No Internet Connection"
                          ? Icons.wifi_off_rounded
                          : Icons.wifi_rounded,
                      color:
                          widget.message == "No Internet Connection"
                              ? Colors.redAccent.shade100
                              : Colors.greenAccent.shade100,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                  ],
                  Flexible(
                    child: Text(
                      widget.message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontFamily: 'Gilroy-SemiBold',
                        decoration: TextDecoration.none,
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
