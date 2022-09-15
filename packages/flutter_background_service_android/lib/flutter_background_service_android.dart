library flutter_background_service_android;

import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service_platform_interface/flutter_background_service_platform_interface.dart';

@pragma('vm:entry-point')
Future<void> entrypoint() async {
  WidgetsFlutterBinding.ensureInitialized();
  final service = AndroidServiceInstance._();
  final int handle = await service._getHandler();
  final callbackHandle = CallbackHandle.fromRawHandle(handle);
  final onStart = PluginUtilities.getCallbackFromHandle(callbackHandle);
  if (onStart != null) {
    onStart(service);
  }
}

class FlutterBackgroundServiceAndroid extends FlutterBackgroundServicePlatform {
  /// Registers this class as the default instance of [FlutterBackgroundServicePlatform].
  static void registerWith() {
    FlutterBackgroundServicePlatform.instance = FlutterBackgroundServiceAndroid();
  }

  static const MethodChannel _channel = const MethodChannel(
    'id.flutter/background_service_android',
    JSONMethodCodec(),
  );

  Future<dynamic> _handle(MethodCall call) async {
    switch (call.method) {
      case "onReceiveData":
        _controller.sink.add(call.arguments);
        break;
      default:
    }

    return true;
  }

  Future<bool> start() async {
    final result = await _channel.invokeMethod('start');
    return result ?? false;
  }

  Future<bool> configure({
    required IosConfiguration iosConfiguration,
    required AndroidConfiguration androidConfiguration,
  }) async {
    _channel.setMethodCallHandler(_handle);

    final CallbackHandle? handle = PluginUtilities.getCallbackHandle(androidConfiguration.onStart);

    if (handle == null) {
      throw 'onStart method must be a top-level or static function';
    }

    final result = await _channel.invokeMethod(
      "configure",
      {
        "background_handle": handle.toRawHandle(),
        "is_foreground_mode": androidConfiguration.isForegroundMode,
        "auto_start_on_boot": androidConfiguration.autoStart,
        "initial_notification_content": androidConfiguration.initialNotificationContent,
        "initial_notification_title": androidConfiguration.initialNotificationTitle,
        "notification_channel_id": androidConfiguration.notificationChannelId,
        "foreground_notification_id": androidConfiguration.foregroundServiceNotificationId,
      },
    );

    return result ?? false;
  }

  Future<bool> isServiceRunning() async {
    var result = await _channel.invokeMethod("isServiceRunning");
    return result ?? false;
  }

  final _controller = StreamController.broadcast(sync: true);

  void dispose() {
    _controller.close();
  }

  @override
  void invoke(String method, [Map<String, dynamic>? args]) {
    _channel.invokeMethod("sendData", {
      'method': method,
      'args': args,
    });
  }

  @override
  Stream<Map<String, dynamic>?> on(String method) {
    return _controller.stream.transform(
      StreamTransformer.fromHandlers(
        handleData: (data, sink) {
          if (data['method'] == method) {
            sink.add(data['args']);
          }
        },
      ),
    );
  }
}

class AndroidServiceInstance extends ServiceInstance {
  static const MethodChannel _channel = const MethodChannel(
    'id.flutter/background_service_android_bg',
    JSONMethodCodec(),
  );

  AndroidServiceInstance._() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  final _controller = StreamController.broadcast(sync: true);
  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case "onReceiveData":
        _controller.sink.add(call.arguments);
        break;
      default:
    }
  }

  @override
  void invoke(String method, [Map<String, dynamic>? args]) {
    _channel.invokeMethod('sendData', {
      'method': method,
      'args': args,
    });
  }

  @override
  Future<void> stopSelf() async {
    await _channel.invokeMethod("stopService");
  }

  @override
  Stream<Map<String, dynamic>?> on(String method) {
    return _controller.stream.transform(
      StreamTransformer.fromHandlers(
        handleData: (data, sink) {
          if (data['method'] == method) {
            sink.add(data['args']);
          }
        },
      ),
    );
  }

  Future<void> setForegroundNotificationInfo({
    required String title,
    required String content,
  }) async {
    await _channel.invokeMethod("setNotificationInfo", {
      "title": title,
      "content": content,
    });
  }

  /* 디아콘 추가 시작 */
  Future<void> setForegroundNotificationInfoLargeIcon({
    required String title,
    required String content,
    required String largeIconPath,
  }) async {
    await _channel.invokeMethod("setNotificationInfoLargeIcon", {
      "title": title,
      "content": content,
      "largeIcon": largeIconPath,
    });
  }
  /* 디아콘 추가 끝 */

  Future<void> setAsForegroundService() async {
    await _channel.invokeMethod("setForegroundMode", {
      'value': true,
    });
  }

  Future<void> setAsBackgroundService() async {
    await _channel.invokeMethod("setForegroundMode", {
      'value': false,
    });
  }

  Future<int> _getHandler() async {
    return await _channel.invokeMethod('getHandler');
  }

  Future<void> setAutoStartOnBootMode(bool value) async {
    await _channel.invokeMethod("setAutoStartOnBootMode", {
      "value": value,
    });
  }
}
