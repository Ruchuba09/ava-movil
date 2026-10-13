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
  final String hint;
  final ValueChanged<T?> onChanged;
  final String? Function(T?)? validator;

  const SelectionField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
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
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.72,
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
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(12),
                      itemCount: options.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final option = options[index];
                        final selected = option.value == value;
                        return Material(
                          color: selected
                              ? verde5Color.withValues(alpha: 0.2)
                              : (isDark ? Colors.white10 : verde1Color),
                          borderRadius: BorderRadius.circular(8),
                          child: ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 2),
                            title: Text(option.label),
                            trailing: selected
                                ? const Icon(Icons.check_circle,
                                    color: verde6Color)
                                : null,
                            onTap: () =>
                                Navigator.pop(sheetContext, option.value),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );

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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
