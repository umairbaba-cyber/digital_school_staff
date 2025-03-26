// ignore_for_file: use_build_context_synchronously
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:eschool_saas_staff/cubits/downloadFileCubit.dart';
import 'package:eschool_saas_staff/data/models/assignmentSubmission.dart';
import 'package:eschool_saas_staff/data/models/studyMaterial.dart';
import 'package:eschool_saas_staff/data/repositories/authRepository.dart';
import 'package:eschool_saas_staff/ui/widgets/customTextContainer.dart';
import 'package:eschool_saas_staff/ui/widgets/downloadFileBottomsheetContainer.dart';
import 'package:eschool_saas_staff/utils/constants.dart';
import 'package:eschool_saas_staff/utils/labelKeys.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' as intl;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

class Utils {
  static Locale getLocaleFromLanguageCode(String languageCode) {
    List<String> result = languageCode.split("-");
    return result.length == 1
        ? Locale(result.first)
        : Locale(result.first, result.last);
  }

  static String getImagePath(String imageName) {
    return "assets/images/$imageName";
  }

  static String getLottieAnimationPath(String animationFileName) {
    return "assets/animations/$animationFileName";
  }

  static String getFormattedDate(DateTime date) {
    return intl.DateFormat('dd-MM-yyyy').format(date).toString();
  }

  static String getFormattedDayOfTime(TimeOfDay time) {
    return "${time.hour}:${time.minute}";
  }

  static String formatDateAndTime(DateTime dateTime) {
    return intl.DateFormat("dd-MM-yyyy, kk:mm").format(dateTime);
  }

  static Future<dynamic> showBottomSheet(
      {required Widget child,
      required BuildContext context,
      bool? enableDrag}) async {
    final result = Get.bottomSheet(child,
        enableDrag: enableDrag ?? true,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(bottomsheetBorderRadius),
                topRight: Radius.circular(bottomsheetBorderRadius))));
    return result;
  }

  static Future<void> showSnackBar({
    required String message,
    required BuildContext context,
    TextStyle? messageTextStyle,
  }) async {
    Get.snackbar(
      "",
      "",
      duration: snackBarDuration,
      titleText: const SizedBox(),
      messageText: CustomTextContainer(
        textKey: message,
        style: messageTextStyle ??
            TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 15.5,
              color: Theme.of(context).colorScheme.secondary,
            ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12.5, horizontal: 15),
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  static intl.DateFormat hourMinutesDateFormat = intl.DateFormat.jm();

  //Date format is dd/mm/yy
  static String formatDate(DateTime dateTime) {
    return intl.DateFormat("dd MMM yyyy").format(dateTime);
  }

  static String formatTime(
      {required TimeOfDay timeOfDay, required BuildContext context}) {
    return timeOfDay.format(context);
  }

  static bool isUserLoggedIn() {
    return AuthRepository.getIsLogIn();
  }

  static Future<bool> hasStoragePermissionGiven() async {
    if (Platform.isIOS) {
      bool permissionGiven = await Permission.storage.isGranted;
      if (!permissionGiven) {
        permissionGiven = (await Permission.storage.request()).isGranted;
        return permissionGiven;
      }
      return permissionGiven;
    }

    //if it is for android
    final deviceInfoPlugin = DeviceInfoPlugin();
    final androidDeviceInfo = await deviceInfoPlugin.androidInfo;
    if (androidDeviceInfo.version.sdkInt < 33) {
      bool permissionGiven = await Permission.storage.isGranted;
      if (!permissionGiven) {
        permissionGiven = (await Permission.storage.request()).isGranted;
        return permissionGiven;
      }
      return permissionGiven;
    } else {
      bool permissionGiven = await Permission.photos.isGranted;
      if (!permissionGiven) {
        permissionGiven = (await Permission.photos.request()).isGranted;
        return permissionGiven;
      }
      return permissionGiven;
    }
  }

  static Future<void> openLinkInBrowser(
      {required String url, required BuildContext context}) async {
    try {
      final canLaunch = await canLaunchUrl(Uri.parse(url));
      if (canLaunch) {
        launchUrl(Uri.parse(url));
      } else {
        Utils.showSnackBar(message: defaultErrorMessageKey, context: context);
      }
    } catch (e) {
      Utils.showSnackBar(message: defaultErrorMessageKey, context: context);
    }
  }

  static String getTranslatedLabel(String labelKey) {
    return labelKey.tr.trim();
  }

  static double appContentTopScrollPadding({required BuildContext context}) {
    return kToolbarHeight + MediaQuery.of(context).padding.top;
  }

  static final List<String> weekDays = [
    mondayKey,
    tuesdayKey,
    wednesdayKey,
    thursdayKey,
    fridayKey,
    saturdayKey,
    sundayKey
  ];

  ///[This will determine this text will take how many number of lines in the ui]
  static int calculateLinesForGivenText(
      {required double availableMaxWidth,
      required BuildContext context,
      required String text,
      required TextStyle textStyle}) {
    final span = TextSpan(
      text: text,
      style: textStyle,
    );
    final tp =
        TextPainter(text: span, textDirection: Directionality.of(context));
    tp.layout(maxWidth: availableMaxWidth);
    final numLines = tp.computeLineMetrics().length;

    return numLines;
  }

  static Future<void> launchCallLog({required String mobile}) async {
    try {
      launchUrl(Uri.parse("tel:$mobile"));
    } catch (_) {}
  }

  static Future<void> launchEmailLog({required String email}) async {
    try {
      launchUrl(Uri.parse("mailto:$email"));
    } catch (_) {}
  }

  static int getHourFromTimeDetails({required String time}) {
    final timeDetails = time.split(":");
    return int.parse(timeDetails[0]);
  }

  static int getMinuteFromTimeDetails({required String time}) {
    final timeDetails = time.split(":");
    return int.parse(timeDetails[1]);
  }

  static void viewOrDownloadStudyMaterial({
    required BuildContext context,
    required bool storeInExternalStorage,
    required StudyMaterial studyMaterial,
  }) {
    try {
      if (studyMaterial.studyMaterialType ==
              StudyMaterialType.uploadedVideoUrl ||
          studyMaterial.studyMaterialType == StudyMaterialType.youtubeVideo) {
        launchUrl(Uri.parse(studyMaterial.fileUrl));
      } else {
        Utils.openDownloadBottomsheet(
          context: context,
          studyMaterial: studyMaterial,
        );
      }
    } catch (e) {
      if (context.mounted) {
        Utils.showSnackBar(
          context: context,
          message: Utils.getTranslatedLabel(unableToOpenFileKey),
        );
      }
    }
  }

  static void openDownloadBottomsheet({
    required BuildContext context,
    required StudyMaterial studyMaterial,
  }) {
    showBottomSheet(
      child: BlocProvider(
        create: (context) => DownloadFileCubit(),
        child: DownloadFileBottomsheetContainer(
          studyMaterial: studyMaterial,
        ),
      ),
      context: context,
    ).then((result) {
      if (result != null) {
        if (result['error']) {
          showSnackBar(
            context: context,
            message: getTranslatedLabel(
              result['message'].toString(),
            ),
          );
        } else {
          try {
            OpenFilex.open(result['filePath'].toString());
          } catch (e) {
            showSnackBar(
              context: context,
              message: getTranslatedLabel(
                unableToOpenFileKey,
              ),
            );
          }
        }
      }
    });
  }

  static Widget buildProgressContainer({
    required double width,
    required Color color,
  }) {
    return Container(
      width: width,
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(3.0)),
    );
  }

  static Future<DateTime?> openDatePicker(
      {required BuildContext context,
      DateTime? lastDate,
      DateTime? inititalDate,
      DateTime? firstDate}) async {
    return await showDatePicker(
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  onPrimary: Theme.of(context).scaffoldBackgroundColor,
                ),
          ),
          child: child!,
        );
      },
      context: context,
      initialDate: inititalDate ?? DateTime.now(),
      firstDate: firstDate ?? DateTime.now(),
      lastDate: lastDate ??
          DateTime.now().add(
            const Duration(days: 30),
          ),
    );
  }

  static Future<TimeOfDay?> openTimePicker(
      {required BuildContext context}) async {
    return await showTimePicker(
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  onPrimary: Theme.of(context).scaffoldBackgroundColor,
                ),
          ),
          child: child!,
        );
      },
      context: context,
      initialTime: TimeOfDay.now(),
    );
  }

  static Future<FilePickerResult?> openFilePicker(
      {required BuildContext context,
      bool allowMultiple = true,
      FileType type = FileType.any}) async {
    Future<FilePickerResult?> pickFiles() async {
      return await FilePicker.platform
          .pickFiles(allowMultiple: allowMultiple, type: type);
    }

    final permission = await Permission.storage.request();
    if (permission.isGranted) {
      return await pickFiles();
    } else {
      try {
        return await pickFiles();
      } on Exception {
        if (context.mounted) {
          Utils.showSnackBar(
              context: context, message: allowStoragePermissionToContinueKey);
          await Future.delayed(const Duration(seconds: 2));
        }
        openAppSettings();
      }
    }
    return null;
  }

  static AssignmentSubmissionStatus getAssignmentSubmissionStatusFromTypeId(
      {required int typeId}) {
    return allAssignmentSubmissionStatus
            .firstWhereOrNull((element) => element.typeStatusId == typeId) ??
        allAssignmentSubmissionStatus.first;
  }

  static bool _shouldUpdateBasedOnVersion(
    String currentVersion,
    String updatedVersion,
  ) {
    List<int> currentVersionList =
        currentVersion.split(".").map((e) => int.parse(e)).toList();
    List<int> updatedVersionList =
        updatedVersion.split(".").map((e) => int.parse(e)).toList();

    if (updatedVersionList[0] > currentVersionList[0]) {
      return true;
    }
    if (updatedVersionList[1] > currentVersionList[1]) {
      return true;
    }
    if (updatedVersionList[2] > currentVersionList[2]) {
      return true;
    }

    return false;
  }

  static Future<bool> forceUpdate(String updatedVersion) async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    String currentVersion = "${packageInfo.version}+${packageInfo.buildNumber}";
    if (updatedVersion.isEmpty) {
      return false;
    }

    final bool updateBasedOnVersion = _shouldUpdateBasedOnVersion(
      currentVersion.split("+").first,
      updatedVersion.split("+").first,
    );

    if (updatedVersion.split("+").length == 1 ||
        currentVersion.split("+").length == 1) {
      return updateBasedOnVersion;
    }

    final bool updateBasedOnBuildNumber = _shouldUpdateBasedOnBuildNumber(
      currentVersion.split("+").last,
      updatedVersion.split("+").last,
    );

    return updateBasedOnVersion || updateBasedOnBuildNumber;
  }

  static bool _shouldUpdateBasedOnBuildNumber(
    String currentBuildNumber,
    String updatedBuildNumber,
  ) {
    return int.parse(updatedBuildNumber) > int.parse(currentBuildNumber);
  }

  static bool isRTLEnabled(BuildContext context) {
    return Directionality.of(context).name == TextDirection.rtl.name;
  }
}

extension DateTimeExtension on DateTime {
  bool isSameDayAs(DateTime other) =>
      day == other.day && month == other.month && year == other.year;

  String get relativeFormatedDate {
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));

    if (isSameDayAs(today)) {
      return "today";
    } else if (isSameDayAs(yesterday)) {
      return "yesterday";
    } else {
      return intl.DateFormat('d MMMM yyyy').format(this);
    }
  }
}
