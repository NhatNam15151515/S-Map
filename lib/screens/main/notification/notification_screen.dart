import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/enums/enums.dart';
import 'package:s_map/commons/mixin/mixin.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/screens/main/notification/widgets/widgets.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  _NotificationScreenState createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen>
    with AppMixin, ListenComingNotification {
  NotificationTab filterPicked = NotificationTab.system;

  final ScrollController _systemScrollController = ScrollController();
  final ScrollController _customerScrollController = ScrollController();

  @override
  void initState() {
    super.initState();


    _systemScrollController.addListener(() {
      if (_systemScrollController.position.pixels >=
          _systemScrollController.position.maxScrollExtent - 200) {
        notiCubit.loadMore(NotificationTab.system);
      }
    });

    _customerScrollController.addListener(() {
      if (_customerScrollController.position.pixels >=
          _customerScrollController.position.maxScrollExtent - 200) {
        notiCubit.loadMore(NotificationTab.customer);
      }
    });

    notiCubit.loadSystemNotifications();
    notiCubit.loadCustomerNotifications();
  }

  @override
  void dispose() {
    _systemScrollController.dispose();
    _customerScrollController.dispose();
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
          NotificationTabFilter(
            selectedTab: filterPicked,
            onTabChanged: (tab) => setState(() => filterPicked = tab),
          ),
          Expanded(
            child: BlocConsumer<NotificationCubit, NotificationState>(
              listener: (context, state) {
                if (state.errorMessage != null) {
                  showError(state.errorMessage!);
                }
              },
              builder: (context, state) {
                final isSystem = filterPicked == NotificationTab.system;
                final items = isSystem
                    ? state.systemNotifications
                    : state.customerNotifications;
                final isLoading = isSystem
                    ? state.isSystemLoading && items.isEmpty
                    : state.isCustomerLoading && items.isEmpty;
                final scrollController = isSystem
                    ? _systemScrollController
                    : _customerScrollController;

                if (isLoading) {
                  return const DefaultListingShimmer();
                }

                if (items.isEmpty) {
                  return RefreshIndicator(
                    color: AppColors.sMapTeal,
                    onRefresh: () => notiCubit.refresh(filterPicked),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        height: MediaQuery.sizeOf(context).height * 0.6,
                        child: EmptyWidget(
                          title: tr(LocaleKeys.noNotification),
                          subtitle: tr(LocaleKeys.noNotificationSubtitle),
                          icon: Icons.notifications_none_rounded,
                        ),
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  color: AppColors.sMapTeal,
                  onRefresh: () => notiCubit.refresh(filterPicked),
                  child: MediaQuery.removePadding(
                    context: context,
                    removeTop: true,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return NotificationItemCard(item: item);
                      },
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: items.length,
                      controller: scrollController,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void onComingNotification(NotificationModel? event) {
    if (event?.notiType == NotificationType.system) {
      notiCubit.refresh(NotificationTab.system);
    }
  }
}
