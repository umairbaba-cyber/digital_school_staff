// ignore_for_file: library_prefixes

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:eschool_saas_staff/app/routes.dart';
import 'package:eschool_saas_staff/data/models/notificationDetails.dart'
    as notificationDetails;
import 'package:eschool_saas_staff/data/repositories/announcementRepository.dart';
import 'package:eschool_saas_staff/data/repositories/authRepository.dart';
import 'package:eschool_saas_staff/utils/api.dart';
import 'package:eschool_saas_staff/utils/hiveBoxKeys.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:path_provider/path_provider.dart';

class NotificationUtility {
  static String notificationType = "Notification";
  static String leaveType = "Leave";
  static String messageType = "Message";

  //
  @pragma('vm:entry-point')
  static Future<void> onBackgroundMessage(RemoteMessage remoteMessage) async {
    final additionalData = remoteMessage.data;
    final type = (additionalData['type'] ?? "").toString();

    if (kDebugMode) {
      print(remoteMessage.toMap());
    }

    if (type == notificationType) {
      await Hive.initFlutter();
      await Hive.openBox(authBoxKey);
      await AnnouncementRepository.addNotificationTemporarily(
          data: notificationDetails.NotificationDetails(
        createdAt: DateTime.now().toString(),
        id: AuthRepository.getUserDetails().id,
        image: remoteMessage.data['image'] ?? "",
        message: remoteMessage.notification?.body ?? "",
        title: remoteMessage.notification?.title ?? "",
      ).toJson());
    }
  }

  static void _onTapNotificationScreenNavigateCallback({
    required Map<String, dynamic> notificationData,
  }) {
    final type = (notificationData['type'] ?? "").toString();

    if (type.isNotEmpty) {
      if (type == notificationType) {
        Get.toNamed(Routes.notificationsScreen);
      } else if (type == leaveType) {
        Get.toNamed(Routes.leaveRequestScreen);
      } else if (type == messageType) {
        if (Get.currentRoute != Routes.chatContacts) {
          Get.toNamed(Routes.chatContacts);
        }
      }
    }
  }

  static final FlutterLocalNotificationsPlugin
      _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  //

  //Ask notification permission here
  static Future<NotificationSettings> _getNotificationPermission() async {
    return await FirebaseMessaging.instance.requestPermission(
      alert: false,
      announcement: false,
      badge: false,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
    );
  }

  static Future<void> setUpNotificationService() async {
    NotificationSettings notificationSettings =
        await FirebaseMessaging.instance.getNotificationSettings();

    //ask for permission
    if (notificationSettings.authorizationStatus ==
        AuthorizationStatus.notDetermined) {
      notificationSettings = await _getNotificationPermission();

      //if permission is provisionnal or authorised
      if (notificationSettings.authorizationStatus ==
              AuthorizationStatus.authorized ||
          notificationSettings.authorizationStatus ==
              AuthorizationStatus.provisional) {
        _initNotificationListener();
      }

      //if permission denied
    } else if (notificationSettings.authorizationStatus ==
        AuthorizationStatus.denied) {
      //If user denied then ask again
      notificationSettings = await _getNotificationPermission();
      if (notificationSettings.authorizationStatus ==
          AuthorizationStatus.denied) {
        return;
      }
    }
    _initNotificationListener();
  }

  static void _initNotificationListener() {
    if (kDebugMode) {
      print("Notification setup done");
    }
    FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: false, // Required to display a heads up notification
      badge: false,
      sound: false,
    );
    FirebaseMessaging.onMessage.listen(foregroundMessageListener);
    FirebaseMessaging.onBackgroundMessage(onBackgroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(onMessageOpenedAppListener);

    FirebaseMessaging.instance.getInitialMessage().then((value) {
      if (kDebugMode) {
        print("Initial notification");
        print(value?.toMap());
      }
      _onTapNotificationScreenNavigateCallback(
        notificationData: value?.data ?? {},
      );
    });

    if (!kIsWeb) {
      _initLocalNotification();
    }
  }

  static void foregroundMessageListener(RemoteMessage remoteMessage) async {
    //await FirebaseMessaging.instance.getToken();

    final additionalData = remoteMessage.data;

    final type = (additionalData['type'] ?? "").toString();

    if (type == notificationType) {
      AnnouncementRepository.addNotification(
          notificationDetails: notificationDetails.NotificationDetails(
        createdAt: DateTime.now().toString(),
        id: AuthRepository.getUserDetails().id,
        image: remoteMessage.data['image'] ?? "",
        message: remoteMessage.notification?.body ?? "",
        title: remoteMessage.notification?.title ?? "",
      ));
    }

    createLocalNotification(
        dismissable: true,
        imageUrl: (additionalData['image'] ?? "").toString(),
        title: remoteMessage.notification?.title ?? "You have new notification",
        body: remoteMessage.notification?.body ?? "",
        payload: jsonEncode(additionalData));
  }

  static void onMessageOpenedAppListener(RemoteMessage remoteMessage) {
    _onTapNotificationScreenNavigateCallback(
        notificationData: remoteMessage.data);
  }

  static void _initLocalNotification() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();

    InitializationSettings initializationSettings =
        const InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    _requestPermissionsForIos();
    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) async {
        _onTapNotificationScreenNavigateCallback(
            notificationData:
                Map<String, dynamic>.from(jsonDecode(details.payload ?? "")));
      },
    );
  }

  static Future<void> _requestPermissionsForIos() async {
    if (Platform.isIOS) {
      _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions();
    }
  }

  static Future<void> createLocalNotification(
      {required String title,
      required bool dismissable, //User can clear it
      required String body,
      required String imageUrl,
      required String payload}) async {
    late AndroidNotificationDetails androidPlatformChannelSpecifics;
    if (imageUrl.isNotEmpty) {
      final downloadedImagePath = await _downloadAndSaveFile(imageUrl);
      if (downloadedImagePath.isEmpty) {
        //If somwhow failed to download image
        androidPlatformChannelSpecifics = AndroidNotificationDetails(
            'com.global.talent.competition', //channel id
            'Local notification',

            //channel name
            importance: Importance.max,
            priority: Priority.high,
            ongoing: !dismissable,
            ticker: 'ticker');
      } else {
        var bigPictureStyleInformation = BigPictureStyleInformation(
            FilePathAndroidBitmap(downloadedImagePath),
            hideExpandedLargeIcon: true,
            contentTitle: title,
            htmlFormatContentTitle: true,
            summaryText: title,
            htmlFormatSummaryText: true);

        androidPlatformChannelSpecifics = AndroidNotificationDetails(
            'com.global.talent.competition', //channel id
            'Local notification', //channel name

            importance: Importance.max,
            priority: Priority.high,
            largeIcon: FilePathAndroidBitmap(downloadedImagePath),
            styleInformation: bigPictureStyleInformation,
            ongoing: !dismissable,
            ticker: 'ticker');
      }
    } else {
      androidPlatformChannelSpecifics = AndroidNotificationDetails(
          'com.global.talent.competition', //channel id
          'Local notification', //channel name

          importance: Importance.max,
          priority: Priority.high,
          ongoing: !dismissable,
          ticker: 'ticker');
    }
    const DarwinNotificationDetails iosNotificationDetails =
        DarwinNotificationDetails();

    var platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics, iOS: iosNotificationDetails);
    await _flutterLocalNotificationsPlugin
        .show(0, title, body, platformChannelSpecifics, payload: payload);
  }

  static Future<String> _downloadAndSaveFile(String url) async {
    final Directory directory = await getApplicationDocumentsDirectory();
    final String filePath = '${directory.path}/temp.jpg';

    try {
      await Api.download(
          url: url,
          cancelToken: CancelToken(),
          savePath: filePath,
          updateDownloadedPercentage: (value) {});

      return filePath;
    } catch (e) {
      return "";
    }
  }
}
