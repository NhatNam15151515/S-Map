import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/enums/enums.dart';
import 'package:s_map/commons/mixin/app_mixin.dart';
import 'package:s_map/commons/mixin/auth_mixin.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/app_colors.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/models/models.dart';
import 'package:flutter/material.dart';

class NotificationScreen extends StatefulWidget {
  static const String path = '/NotificationScreen';

  const NotificationScreen({super.key});

  @override
  _NotificationScreenState createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen>
    with AppMixin, ListenComingNotification {
  NotificationTab filterPicked = NotificationTab.system;
  late GenericListCubit<NotificationModel> systemNotiCubit;
  late GenericListCubit<NotificationModel> customerNotiCubit;

  final ScrollController _systemScrollController = ScrollController();
  final ScrollController _customerScrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    systemNotiCubit = GenericListCubit(
      future: (page, limit) => appRepos.notiRepos
          .getSystemNotification(
        page: page,
        limit: limit,
      )
          .then((value) {
        notiCubit.applyStats(NotificationTab.system, value.$2);
        return value.$1;
      }),
      limit: 10,
    );

    customerNotiCubit = GenericListCubit(
      future: (page, limit) => appRepos.notiRepos
          .getCustomerNotification(
        page: page,
        limit: limit,
      )
          .then((value) {
        notiCubit.applyStats(NotificationTab.customer, value.$2);
        return value.$1;
      }),
      limit: 10,
    );

    _systemScrollController.addListener(() {
      if (_systemScrollController.position.pixels >=
          _systemScrollController.position.maxScrollExtent - 200) {
        systemNotiCubit.loadMore();
      }
    });

    _customerScrollController.addListener(() {
      if (_customerScrollController.position.pixels >=
          _customerScrollController.position.maxScrollExtent - 200) {
        customerNotiCubit.loadMore();
      }
    });

    systemNotiCubit.request();
    customerNotiCubit.request();
  }

  @override
  void dispose() {
    _systemScrollController.dispose();
    _customerScrollController.dispose();
    systemNotiCubit.close();
    customerNotiCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TitleAppBar(
        title: tr(LocaleKeys.notification),
      ),
      body: Column(
        children: [
          filter(),
          Expanded(
            child: IndexedStack(
              index: filterPicked == NotificationTab.system ? 0 : 1,
              children: [
                _listBody(systemNotiCubit, _systemScrollController),
                _listBody(customerNotiCubit, _customerScrollController),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _listBody(
    GenericListCubit<NotificationModel> cubit,
    ScrollController scrollController,
  ) {
    return RefreshIndicator(
      color: AppColors.sMapTeal,
      onRefresh: () async {
        await cubit.refresh();
      },
      child: BlocConsumer<GenericListCubit<NotificationModel>,
          GenericListState<NotificationModel>>(
        bloc: cubit,
        listener: (context, state) {
          if (state.type == GenericListStateType.error &&
              state.errorMessage != null) {
            showError(state.errorMessage?.message);
          }
        },
        builder: (context, state) {
          if (state.type == GenericListStateType.loading) {
            return const DefaultListingShimmer();
          }
          final list = state.value;

          if (list.isEmpty) {
            return EmptyWidget(
              title: tr(LocaleKeys.noNotification),
              subtitle: tr(LocaleKeys.noNotificationSubtitle),
              icon: Icons.notifications_none_rounded,
            );
          }
          return MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              separatorBuilder: (context, index) {
                return const SizedBox(height: 8);
              },
              itemBuilder: (context, index) {
                final item = list[index];
                return _notificationCard(item);
              },
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: list.length,
              controller: scrollController,
            ),
          );
        },
      ),
    );
  }

  Widget _notificationCard(NotificationModel item) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.outlineVariant.withAlpha(128),
          width: 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.sMapLightTeal,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.notifications_rounded,
                    size: 20,
                    color: AppColors.sMapTeal,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "${item.content}",
                    style: styles.blackTextColor.textTheme.textStyle.copyWith(
                      fontSize: 14,
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget filter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: NotificationTab.values.map((e) {
          final picked = filterPicked == e;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              selected: picked,
              onSelected: (selected) {
                setState(() {
                  filterPicked = e;
                });
              },
              label: Text(
                e.title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: picked ? FontWeight.w600 : FontWeight.w400,
                  color: picked
                      ? AppColors.sMapDarkTeal
                      : AppColors.onSurfaceVariant,
                ),
              ),
              selectedColor: AppColors.sMapLightTeal,
              backgroundColor: AppColors.surfaceContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide.none,
              ),
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  void onComingNotification(NotificationModel? event) {
    if (event?.notiType == NotificationType.system) {
      systemNotiCubit.refresh();
    }
  }
}
