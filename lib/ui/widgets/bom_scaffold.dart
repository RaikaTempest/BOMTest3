import 'package:flutter/material.dart';

/// Provides a gradient backdrop that mirrors the refreshed BOM Builder
/// aesthetic while still exposing the familiar [Scaffold] API.
class BomScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomNavigationBar;
  final Widget? bottomSheet;
  final bool extendBody;

  const BomScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
    this.bottomSheet,
    this.extendBody = true,
  });

  @override
  Widget build(BuildContext context) {
    final gradient = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF020817),
        Color(0xFF041331),
        Color(0xFF061C3F),
      ],
    );

    return DecoratedBox(
      decoration: BoxDecoration(gradient: gradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: extendBody,
        appBar: appBar,
        body: body,
        floatingActionButton: floatingActionButton,
        floatingActionButtonLocation:
            floatingActionButtonLocation ?? FloatingActionButtonLocation.endFloat,
        bottomNavigationBar: bottomNavigationBar,
        bottomSheet: bottomSheet,
      ),
    );
  }
}
