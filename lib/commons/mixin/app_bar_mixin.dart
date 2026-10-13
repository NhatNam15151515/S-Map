import 'package:s_map/routers/routers.dart';
import 'package:flutter/cupertino.dart';

mixin AppBarMixin implements PreferredSizeWidget {
  double get appBarHeight {
    final ctx = _appContext;
    if (ctx != null) {
      try {
        return appBarDesignHeight + MediaQuery.paddingOf(ctx).top;
      } catch (_) {
        return appBarDesignHeight;
      }
    }
    return appBarDesignHeight;
  }

  double get appBarDesignHeight;

  BuildContext? get _appContext {
    try {
      return Routes.instance.context;
    } catch (_) {
      return null;
    }
  }

  @override
  Size get preferredSize => Size.fromHeight(appBarHeight);
}
