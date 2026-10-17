/// List/detail (master–detail): on phones, tapping an item pushes its detail
/// page; on wide windows the list and the selected item's detail sit side
/// by side.
///
/// Newly written. Every source app had list → detail navigation (notes,
/// recipes, memories) but none adapted it for tablets, where a full-screen
/// detail page wastes most of the screen.
///
/// ```dart
/// ListDetailScaffold<Note>(
///   title: 'Notes',
///   items: notes,
///   idOf: (n) => n.id,
///   tileBuilder: (context, note, selected, open) =>
///       ListTile(title: Text(note.title), selected: selected, onTap: open),
///   detailBuilder: (context, note) => NoteDetail(note),
///   detailTitleOf: (n) => n.title,
/// )
/// ```
library;

import 'package:flutter/material.dart';

import '../03_feedback/state_views.dart';

class ListDetailScaffold<T> extends StatefulWidget {
  const ListDetailScaffold({
    super.key,
    required this.title,
    required this.items,
    required this.idOf,
    required this.tileBuilder,
    required this.detailBuilder,
    this.detailTitleOf,
    this.initialSelectedId,
    this.breakpoint = 840,
    this.listWidth = 360,
    this.emptyDetail,
  });

  final String title;
  final List<T> items;
  final String Function(T item) idOf;

  /// Build a list row. Call `open` to show the item's detail.
  final Widget Function(
    BuildContext context,
    T item,
    bool selected,
    VoidCallback open,
  )
  tileBuilder;
  final Widget Function(BuildContext context, T item) detailBuilder;

  /// App-bar title of the pushed detail page on phones.
  final String Function(T item)? detailTitleOf;
  final String? initialSelectedId;

  /// Width from which list and detail are shown side by side.
  final double breakpoint;
  final double listWidth;

  /// Shown in the detail pane when nothing is selected (wide layout).
  final Widget? emptyDetail;

  @override
  State<ListDetailScaffold<T>> createState() => _ListDetailScaffoldState<T>();
}

class _ListDetailScaffoldState<T> extends State<ListDetailScaffold<T>> {
  late String? _selectedId = widget.initialSelectedId;

  T? get _selected {
    for (final item in widget.items) {
      if (widget.idOf(item) == _selectedId) return item;
    }
    return null; // deleted, or nothing selected
  }

  void _open(T item, bool wide) {
    setState(() => _selectedId = widget.idOf(item));
    if (wide) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(widget.detailTitleOf?.call(item) ?? '')),
          body: widget.detailBuilder(context, item),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= widget.breakpoint;
    final list = ListView.builder(
      itemCount: widget.items.length,
      itemBuilder: (context, i) {
        final item = widget.items[i];
        return widget.tileBuilder(
          context,
          item,
          wide && widget.idOf(item) == _selectedId,
          () => _open(item, wide),
        );
      },
    );

    if (!wide) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: list,
      );
    }
    final selected = _selected;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Row(
        children: [
          SizedBox(width: widget.listWidth, child: list),
          const VerticalDivider(width: 1),
          Expanded(
            child: selected == null
                ? (widget.emptyDetail ??
                      const EmptyView(
                        icon: Icons.touch_app_outlined,
                        title: 'Select an item',
                      ))
                : KeyedSubtree(
                    key: ValueKey(_selectedId),
                    child: widget.detailBuilder(context, selected),
                  ),
          ),
        ],
      ),
    );
  }
}
