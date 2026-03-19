import 'package:flutter/material.dart';

class SearchBar extends StatefulWidget {
  final String hintText;
  final TextStyle? hintStyle;
  final ValueChanged<String> onChanged;
  final VoidCallback onQueryCleared;
  final FocusNode focusNode;
  final Color? backgroundColor;
  final Color? searchIconColor;
  final Color? clearIconColor;
  final TextStyle? textStyle;

  const SearchBar({
    super.key,
    required this.hintText,
    this.hintStyle,
    required this.onChanged,
    required this.onQueryCleared,
    required this.focusNode,
    this.backgroundColor,
    this.searchIconColor,
    this.clearIconColor,
    this.textStyle,
  });

  @override
  _SearchBarState createState() => _SearchBarState();
}

class _SearchBarState extends State<SearchBar> {
  final TextEditingController _textController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
    _textController.addListener(() {
      if (mounted) {
        setState(() {
          _isSearching = _textController.text.isNotEmpty;
        });
      }
    });
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    _textController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() {
        // _isSearching = widget.focusNode.hasFocus; // Keep _isSearching based on text content
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final defaultTextStyle =
        theme.textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface);
    final effectiveTextStyle = widget.textStyle ?? defaultTextStyle;
    final effectiveHintStyle = widget.hintStyle ??
        theme.textTheme.bodyLarge
            ?.copyWith(color: colorScheme.onSurfaceVariant);
    final effectiveBackgroundColor =
        widget.backgroundColor ?? colorScheme.surfaceVariant.withOpacity(0.9);
    final effectiveSearchIconColor =
        widget.searchIconColor ?? colorScheme.onSurfaceVariant;
    final effectiveClearIconColor =
        widget.clearIconColor ?? colorScheme.onSurfaceVariant;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 6.0),
      padding: const EdgeInsets.symmetric(horizontal: 0),
      decoration: BoxDecoration(
        color: effectiveBackgroundColor,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: widget.focusNode.hasFocus
              ? colorScheme.primary
              : colorScheme.outlineVariant,
          width: widget.focusNode.hasFocus ? 2.0 : 1.0,
        ),
        boxShadow: [
          if (widget.focusNode.hasFocus)
            BoxShadow(
              color: colorScheme.primary.withOpacity(0.10),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 12.0, right: 6.0),
              child:
                  Icon(Icons.search, color: effectiveSearchIconColor, size: 26),
            ),
            Expanded(
              child: TextField(
                controller: _textController,
                focusNode: widget.focusNode,
                onChanged: widget.onChanged,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: widget.hintText,
                  hintStyle: effectiveHintStyle,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 12.0, horizontal: 0.0),
                ),
                style: effectiveTextStyle?.copyWith(fontSize: 16),
              ),
            ),
            if (_isSearching)
              Padding(
                padding: const EdgeInsets.only(right: 6.0),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    _textController.clear();
                    widget.onQueryCleared();
                  },
                  child: Icon(Icons.clear,
                      color: effectiveClearIconColor, size: 20),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
