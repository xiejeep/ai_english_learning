import 'package:flutter/material.dart';

class MessageInput extends StatefulWidget {
  final TextEditingController controller;
  final bool isLoading;
  final bool isStreaming;
  final VoidCallback? onSend;
  final VoidCallback? onStop;
  final String? hintText;
  // final bool autofocus;
  final bool enableInteractiveSelection;

  const MessageInput({
    super.key,
    required this.controller,
    this.isLoading = false,
    this.isStreaming = false,
    this.onSend,
    this.onStop,
    this.hintText,
    // this.autofocus = false,
    this.enableInteractiveSelection = true,
  });

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  bool _isEmpty = true;
  FocusNode? _focusNode;

  @override
  void initState() {
    super.initState();
    _createFocusNode();
    widget.controller.addListener(_onTextChanged);
    _isEmpty = widget.controller.text.trim().isEmpty;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode?.removeListener(_onFocusChanged);
    _focusNode?.dispose();
    super.dispose();
  }

  void _createFocusNode() {
    _focusNode?.removeListener(_onFocusChanged);
    _focusNode?.dispose();
    _focusNode = FocusNode();
    _focusNode!.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    // 当焦点失去时，延迟重置 FocusNode 以清除"记忆"
    if (!_focusNode!.hasFocus) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && !_focusNode!.hasFocus) {
          // 重新创建 FocusNode 来彻底清除焦点历史
          setState(() {
            _createFocusNode();
          });
        }
      });
    }
  }

  void _onTextChanged() {
    final isEmpty = widget.controller.text.trim().isEmpty;
    if (_isEmpty != isEmpty) {
      setState(() {
        _isEmpty = isEmpty;
      });
    }
  }

  void _handleSend() {
    if (!_isEmpty && !widget.isLoading && !widget.isStreaming) {
      widget.onSend?.call();
    }
  }

  void _handleStop() {
    if (widget.isStreaming) {
      widget.onStop?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outline.withOpacity(0.2)),
        ),
      ),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // 输入框
            Expanded(
              child: Container(
                constraints: const BoxConstraints(
                  minHeight: 48,
                  maxHeight: 120,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(
                    0.5,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.3),
                  ),
                ),
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  enableInteractiveSelection: widget.enableInteractiveSelection,
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _handleSend(),
                  decoration: InputDecoration(
                    hintText: widget.hintText ?? '输入你想练习的内容...',
                    hintStyle: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 发送/停止按钮
            _buildActionButton(context, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, ThemeData theme) {
    late final IconData icon;
    late final VoidCallback? onPressed;
    late final Color backgroundColor;
    late final Color iconColor;

    if (widget.isStreaming) {
      // 流式响应中，显示停止按钮
      icon = Icons.stop;
      onPressed = _handleStop;
      backgroundColor = Colors.red;
      iconColor = Colors.white;
    } else if (widget.isLoading) {
      // 加载中，显示加载图标
      icon = Icons.hourglass_empty;
      onPressed = null;
      backgroundColor = theme.colorScheme.outline;
      iconColor = Colors.white;
    } else if (_isEmpty) {
      // 输入为空，显示禁用的发送按钮
      icon = Icons.send;
      onPressed = null;
      backgroundColor = theme.colorScheme.outline;
      iconColor = Colors.white;
    } else {
      // 可以发送，显示激活的发送按钮
      icon = Icons.send;
      onPressed = _handleSend;
      backgroundColor = Theme.of(context).primaryColor;
      iconColor = Colors.white;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 48,
      width: 48,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow:
            onPressed != null
                ? [
                  BoxShadow(
                    color: backgroundColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
                : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(24),
          child:
              widget.isLoading && !widget.isStreaming
                  ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  )
                  : Icon(icon, color: iconColor, size: 20),
        ),
      ),
    );
  }
}
