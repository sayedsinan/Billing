import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:test_bill/core/utils/portion_helper.dart';
import 'package:test_bill/theme/colors.dart';

/// Compact `- [typable qty] +` control.
/// - For normal items: displays numeric count (`1`, `2`, `3`...) and accepts numbers.
/// - For Mandi / F-H-Q items (`isPortion == true`): displays `Q`, `H`, `H+Q`, `F`,
///   `F+Q`, `2F`... and accepts BOTH numbers (`1=Q`, `2=H`, `3=H+Q`, `4=F`) and
///   letter shortcuts (`Q`, `H`, `HQ`, `F`, `FH`, `FHQ`, `2F`, etc.).
class InlineQtyControl extends StatefulWidget {
  final double qty;
  final bool isPortion;
  final Color accentColor;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final ValueChanged<double> onSetQty;
  final double inputWidth;

  const InlineQtyControl({
    super.key,
    required this.qty,
    required this.isPortion,
    required this.accentColor,
    required this.onDecrease,
    required this.onIncrease,
    required this.onSetQty,
    this.inputWidth = 38,
  });

  @override
  State<InlineQtyControl> createState() => _InlineQtyControlState();
}

class _InlineQtyControlState extends State<InlineQtyControl> {
  late TextEditingController _ctrl;
  late FocusNode _focusNode;

  String _formattedQty(double q) => widget.isPortion
      ? PortionHelper.formatPortionQty(q)
      : PortionHelper.formatPlainQty(q);

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: _formattedQty(widget.qty));
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant InlineQtyControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus) {
      final next = _formattedQty(widget.qty);
      if (_ctrl.text != next) {
        _ctrl.text = next;
      }
    }
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      // Select all on focus so typing "F", "H", "Q", "3", etc. replaces immediately.
      _ctrl.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _ctrl.text.length,
      );
    } else {
      _commitInput(_ctrl.text);
    }
  }

  void _commitInput(String raw) {
    final parsed = PortionHelper.parseQtyInput(
      raw,
      allowFHQ: widget.isPortion,
    );
    if (parsed == null) {
      // Revert to current valid qty if input was empty/invalid.
      _ctrl.text = _formattedQty(widget.qty);
      return;
    }
    if (parsed <= 0) {
      widget.onSetQty(0);
      return;
    }
    if ((parsed - widget.qty).abs() > 0.0001) {
      widget.onSetQty(parsed);
    }
    final normalized = _formattedQty(parsed);
    if (_ctrl.text != normalized) {
      _ctrl.text = normalized;
    }
  }

  void _onChanged(String raw) {
    final parsed = PortionHelper.parseQtyInput(
      raw,
      allowFHQ: widget.isPortion,
    );
    if (parsed != null && parsed > 0) {
      widget.onSetQty(parsed);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: widget.accentColor.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () {
              if (_focusNode.hasFocus) _focusNode.unfocus();
              widget.onDecrease();
            },
            borderRadius: BorderRadius.circular(20),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(Icons.remove_circle_rounded, color: kRed, size: 19),
            ),
          ),
          SizedBox(
            width: widget.inputWidth,
            height: 22,
            child: TextField(
              controller: _ctrl,
              focusNode: _focusNode,
              textAlign: TextAlign.center,
              textAlignVertical: TextAlignVertical.center,
              style: TextStyle(
                color: widget.accentColor,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
              keyboardType: widget.isPortion
                  ? TextInputType.text
                  : const TextInputType.numberWithOptions(decimal: true),
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  widget.isPortion
                      ? RegExp(r'[0-9fFhHqQ+\s]')
                      : RegExp(r'[0-9.]'),
                ),
              ],
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              ),
              onChanged: _onChanged,
              onSubmitted: _commitInput,
            ),
          ),
          InkWell(
            onTap: () {
              if (_focusNode.hasFocus) _focusNode.unfocus();
              widget.onIncrease();
            },
            borderRadius: BorderRadius.circular(20),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(Icons.add_circle_rounded, color: kGreen, size: 19),
            ),
          ),
        ],
      ),
    );
  }
}
