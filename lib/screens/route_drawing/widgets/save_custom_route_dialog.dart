import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/generated/locale_keys.g.dart';

class SaveCustomRouteDialog extends StatefulWidget {
  final String initialName;
  final void Function(String name, String? description)? onSave;

  const SaveCustomRouteDialog({
    super.key,
    required this.initialName,
    this.onSave,
  });

  static Future<void> show(
    BuildContext context, {
    required String initialName,
    required void Function(String name, String? description) onSave,
  }) async {
    final result = await showDialog<({String name, String? description})>(
      context: context,
      builder: (dialogCtx) => SaveCustomRouteDialog(
        initialName: initialName,
        onSave: onSave,
      ),
    );
    if (result != null) {
      onSave(result.name, result.description);
    }
  }

  @override
  State<SaveCustomRouteDialog> createState() => _SaveCustomRouteDialogState();
}

class _SaveCustomRouteDialogState extends State<SaveCustomRouteDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _descController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _handleSave() {
    if (_formKey.currentState?.validate() ?? false) {
      final name = _nameController.text.trim();
      final desc = _descController.text.trim().isEmpty
          ? null
          : _descController.text.trim();
      Navigator.of(context).pop((name: name, description: desc));
      widget.onSave?.call(name, desc);
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = AppStyle.of(context);

    return Dialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(LocaleKeys.route_drawing_ui_save_dialog_title),
                style: style.blackTextColor.textTheme.boldStyle.copyWith(
                  fontSize: 18,
                  color: AppColors.grimReaper,
                ),
              ),
              const SizedBox(height: 16),
              // Route Name Field
              Text(
                tr(LocaleKeys.route_drawing_ui_route_name_label),
                style: style.blackTextColor.textTheme.semiBoldStyle.copyWith(
                  fontSize: 13,
                  color: AppColors.sonicSilver,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                key: const Key('save_route_name_input'),
                controller: _nameController,
                style: style.blackTextColor.textTheme.textStyle.copyWith(fontSize: 14),
                decoration: InputDecoration(
                  hintText: tr(LocaleKeys.route_drawing_ui_route_name_hint),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.outlineVariant),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.sMapTeal, width: 1.5),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return tr(LocaleKeys.route_drawing_ui_route_name_required);
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              // Description Field
              Text(
                tr(LocaleKeys.route_drawing_ui_route_desc_label),
                style: style.blackTextColor.textTheme.semiBoldStyle.copyWith(
                  fontSize: 13,
                  color: AppColors.sonicSilver,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                key: const Key('save_route_desc_input'),
                controller: _descController,
                maxLines: 2,
                style: style.blackTextColor.textTheme.textStyle.copyWith(fontSize: 14),
                decoration: InputDecoration(
                  hintText: tr(LocaleKeys.route_drawing_ui_route_desc_hint),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.outlineVariant),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.sMapTeal, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      tr(LocaleKeys.cancel),
                      style: style.blackTextColor.textTheme.mediumStyle.copyWith(
                        fontSize: 14,
                        color: AppColors.sonicSilver,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    key: const Key('save_route_submit_button'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.sMapTeal,
                      foregroundColor: AppColors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: _handleSave,
                    child: Text(
                      tr(LocaleKeys.confirm),
                      style: style.blackTextColor.textTheme.boldStyle.copyWith(
                        fontSize: 14,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
