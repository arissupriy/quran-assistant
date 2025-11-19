import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:quran_assistant/core/download/mushaf_download_preferences.dart';
import 'package:quran_assistant/main_screen.dart';
import 'package:quran_assistant/pages/mushaf/mushaf_detail_page.dart';
import 'package:quran_assistant/pages/mushaf_download_page.dart';

class DownloadNotificationRouter {
  DownloadNotificationRouter._internal();

  static final DownloadNotificationRouter instance = DownloadNotificationRouter._internal();

  static const _channelName = 'quran_assistant/download_notification';
  final MethodChannel _channel = const MethodChannel(_channelName);
  final List<Map<String, dynamic>> _pendingPayloads = <Map<String, dynamic>>[];
  GlobalKey<NavigatorState>? _navigatorKey;
  bool _handlerAttached = false;
  bool _navigatorReady = false;

  void initialize(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
    if (_handlerAttached) return;
    _channel.setMethodCallHandler(_handleMethodCall);
    _handlerAttached = true;
  }

  Future<void> markNavigatorReady() async {
    if (_navigatorReady) return;
    _navigatorReady = true;
    await _flushPendingPayloads();
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method != 'downloadNotificationTap') return;
    final payload = _castPayload(call.arguments);
    await _handlePayload(payload);
  }

  Map<String, dynamic> _castPayload(dynamic raw) {
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return <String, dynamic>{};
  }

  Future<void> _handlePayload(Map<String, dynamic> payload) async {
    if (!_navigatorReady || _navigatorKey?.currentState == null) {
      _pendingPayloads.add(payload);
      return;
    }
    await _routePayload(payload);
  }

  Future<void> _flushPendingPayloads() async {
    if (_pendingPayloads.isEmpty) return;
    final pending = List<Map<String, dynamic>>.from(_pendingPayloads);
    _pendingPayloads.clear();
    for (final payload in pending) {
      await _routePayload(payload);
    }
  }

  Future<void> _routePayload(Map<String, dynamic> payload) async {
    final navigator = _navigatorKey?.currentState;
    if (navigator == null) {
      _pendingPayloads.add(payload);
      return;
    }

    final status = _parseStatus(payload['status']);

    if (status == DownloadTaskStatus.complete) {
      await _openMushafDetail(navigator);
    } else {
      await _openDownloadPage(navigator);
    }
  }

  DownloadTaskStatus? _parseStatus(dynamic statusValue) {
    if (statusValue is int) {
      try {
        return DownloadTaskStatus.fromInt(statusValue);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<void> _openMushafDetail(NavigatorState navigator) async {
    final initialPage = await MushafDownloadPreferences.getInitialPage();
    await MushafDownloadPreferences.clearInitialPage();
    final widget = initialPage != null
        ? MushafDetailPage(pageNumber: initialPage)
        : const MainScreen();
    navigator.push(MaterialPageRoute(builder: (_) => widget));
  }

  Future<void> _openDownloadPage(NavigatorState navigator) async {
    final initialPage = await MushafDownloadPreferences.getInitialPage();
    navigator.push(
      MaterialPageRoute(
        builder: (_) => MushafDownloadPage(initialPage: initialPage),
      ),
    );
  }
}
