import 'package:flutter/material.dart';

class InfiniteList extends StatelessWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  const InfiniteList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (itemCount == 0) return const SizedBox.shrink();
    const centerKey = ValueKey('infinite-center');

    return CustomScrollView(
      center: centerKey,
      slivers: [
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) => itemBuilder(context, itemCount - 1 - (i % itemCount)),
          ),
        ),
        SliverList(
          key: centerKey,
          delegate: SliverChildBuilderDelegate(
            (context, i) => itemBuilder(context, i % itemCount),
          ),
        ),
      ],
    );
  }
}