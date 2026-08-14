import 'package:s_map/commons/mixin/app_mixin.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class DefaultListingShimmer extends StatelessWidget with AppMixin {

  final EdgeInsets? padding;

  const DefaultListingShimmer({super.key, this.padding = const EdgeInsets.symmetric(
    horizontal: 12,
    vertical: 12,
  )});

  @override
  Widget build(BuildContext context) {
    final Color whiteShimmer = Colors.white.withAlpha(77);
    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: Shimmer.fromColors(
        baseColor: Colors.grey.withAlpha(179),
        highlightColor: Colors.grey[100]!.withAlpha(128),
        child: ListView.separated(
          padding: padding,
          itemCount: 20,
          separatorBuilder: (context, index) {
            return const SizedBox(height: 6);
          },
          itemBuilder: (BuildContext context, int index) {
            return Container(
              padding: const EdgeInsets.all(4.0),
              child: Row(
                children: [
                  Container(
                    color: whiteShimmer,
                    height: 35,
                    width: 35,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Container(
                              color: whiteShimmer,
                              height: 14,
                            )),
                            Container(
                              margin: const EdgeInsets.only(left: 10),
                              color: whiteShimmer,
                              height: 14,
                              width: 60,
                            ),
                          ],
                        ),
                        const SizedBox(height: 11),
                        Row(
                          children: [
                            Expanded(child: Container(
                              color: whiteShimmer,
                              height: 14,
                            )),
                            Container(
                              margin: const EdgeInsets.only(left: 10),
                              color: whiteShimmer,
                              height: 14,
                              width: 60,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

