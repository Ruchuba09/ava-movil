import 'package:flutter/material.dart';
import 'package:avamovil/styles/colors.dart';

class SelectionOption<T> {
  final T value;
  final String label;

  const SelectionOption({required this.value, required this.label});
}

class SelectionField<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<SelectionOption<T>> options;
  final List<List<SelectionOption<T>>>? optionRows;
  final bool wrapOptionLabels;
  final String hint;
  final ValueChanged<T?> onChanged;
  final String? Function(T?)? validator;

  const SelectionField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.optionRows,
    this.wrapOptionLabels = false,
    this.hint = 'Selecciona una opción',
    this.validator,
  });

  Future<T?> _select(BuildContext context) => showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height *
                  (wrapOptionLabels ? 0.94 : 0.72),
            ),
            decoration: BoxDecoration(
              color: isDark ? gris2Color : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(label,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                        IconButton(
                          tooltip: 'Cerrar',
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  if (optionRows != null)
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: optionRows!
                            .map(
                              (row) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: row
                                      .map(
                                        (option) => Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 2),
                                            child: _optionTile(
                                                option, isDark, sheetContext),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.all(12),
                        itemCount: options.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 6),
                        itemBuilder: (context, index) =>
                            _optionTile(options[index], isDark, sheetContext),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      );

  Widget _optionTile(
    SelectionOption<T> option,
    bool isDark,
    BuildContext sheetContext,
  ) {
    final selected = option.value == value;
    return Material(
      color: selected
          ? (isDark ? const Color(0xFF34451F) : const Color(0xFFE8F5D7))
          : (isDark ? const Color(0xFF3A4046) : const Color(0xFFF1F3F4)),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => Navigator.pop(sheetContext, option.value),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: EdgeInsets.symmetric(
            horizontal: 14,
            vertical: wrapOptionLabels ? 14 : 10,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  option.label,
                  textAlign: TextAlign.left,
                  maxLines: wrapOptionLabels ? null : 1,
                  overflow: wrapOptionLabels ? null : TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: wrapOptionLabels ? 14 : 13,
                    height: 1.35,
                    color: isDark ? Colors.white : const Color(0xFF202428),
                  ),
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 10),
                const Icon(Icons.check_circle, color: verde6Color, size: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String? selectedLabel;
    for (final option in options) {
      if (option.value == value) {
        selectedLabel = option.label;
        break;
      }
    }

    return FormField<T>(
      initialValue: value,
      validator: validator,
      builder: (field) => InkWell(
        onTap: options.isEmpty
            ? null
            : () async {
                final selected = await _select(context);
                if (selected == null) return;
                field.didChange(selected);
                onChanged(selected);
              },
        borderRadius: BorderRadius.circular(8),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            errorText: field.errorText,
            filled: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  selectedLabel ?? hint,
                  maxLines: wrapOptionLabels ? null : 1,
                  overflow: wrapOptionLabels ? null : TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selectedLabel == null
                        ? Theme.of(context).hintColor
                        : null,
                  ),
                ),
              ),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
      ),
    );
  }
}
