import 'dart:io';

import 'package:s_map/commons/log/log.dart';
import 'package:s_map/flavor/flavor.dart';
import 'package:s_map/models/user.dart';
import 'package:s_map/services/package_info_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';

class FirebaseAnalyticsService {
  FirebaseAnalyticsService._() {
    init();
  }

  static FirebaseAnalyticsService? _instance;
  factory FirebaseAnalyticsService() => _instance ??= FirebaseAnalyticsService._();

  FirebaseAnalytics? get _analytics {
    try {
      if (Firebase.apps.isNotEmpty) {
        return FirebaseAnalytics.instance;
      }
    } catch (_) {}
    return null;
  }

  Future init() async {
    try {
      await PackageInfoService.instance.initCompleter.future;
      await _analytics?.setDefaultEventParameters({
        "version": PackageInfoService.instance.version,
        "platform": Platform.operatingSystem,
        "env": Flavor.instance.name,
      });
    } catch (e) {
      DLog.error("FirebaseAnalytics init error: $e");
    }
  }

  Future resetUserDetail({User? profile}) async {
    try {
      if (_analytics == null) return;
      await Future.wait([
        _analytics!.setUserId(id: profile?.username?.toString()),
        _analytics!.setUserProperty(
          name: 'username',
          value: profile?.username?.toString(),
        ),
      ]);
    } catch (e) {
      DLog.error("FirebaseAnalytics resetUserDetail error: $e");
    }
  }

  Future logEvent(String name, Map<String, dynamic> params) async {
    try {
      if (_analytics == null) return;
      DLog.info("Logging event $name to Analytics, params: ${params.toString()}");
      await _analytics!.logEvent(
        name: name,
        parameters: <String, Object>{
          ...params.map((key, value) => MapEntry(key, value is num ? value : value.toString())),
        },
      );
    } catch (e) {
      DLog.error("FirebaseAnalytics logEvent error: $e");
    }
  }
}

extension LogToFirebaseAnalyticsByFunc on Function {
  Function logFA(String event, {Map<String, dynamic>? params}) => () {
    this();
    FirebaseAnalyticsService().logEvent(event, params ?? {});
  };
}

extension LogToFirebaseAnalyticsByVoidFunc on GestureTapCallback {
  GestureTapCallback logFA(String event, {Map<String, dynamic>? params}) => () {
    this();
    FirebaseAnalyticsService().logEvent(event, params ?? {});
  };
}

extension LogToFirebaseAnalyticsByVoid on void {
  void logFA(String event, {Map<String, dynamic>? params}) => () {
    FirebaseAnalyticsService().logEvent(event, params ?? {});
    return this;
  };
}
