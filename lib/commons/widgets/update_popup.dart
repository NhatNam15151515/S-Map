import 'package:flutter/material.dart';
import 'package:s_map/commons/mixin/mixin.dart';
import 'package:s_map/commons/styles/styles.dart';

class UpdatePopup extends StatelessWidget with AppMixin {
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const UpdatePopup({
    super.key,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withAlpha(191),
      alignment: Alignment.center,
      child: Dialog(
        backgroundColor: styles.greysTextColor.last,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(21)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                //hard code string
                "CSM ORD đã có phiên bản mới. Bạn có muốn cập nhật không?",
                style: styles.blackTextColor.textTheme.textStyle.copyWith(
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 36),
              IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          onCancel();
                        },
                        child: Container(
                          height: double.infinity,
                          alignment: Alignment.center,
                          child: Text(
                            "Không",
                            style: styles
                                .colorScheme
                                .error
                                .textTheme
                                .subTitleStyle
                                .copyWith(fontSize: 13),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          onConfirm();
                        },
                        child: Text(
                          "Có",
                          style: styles
                              .greysTextColor
                              .last
                              .textTheme
                              .subTitleStyle
                              .copyWith(fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
