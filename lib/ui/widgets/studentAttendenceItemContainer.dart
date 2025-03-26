import 'package:eschool_saas_staff/data/models/studentDetails.dart';
import 'package:eschool_saas_staff/ui/styles/themeExtensions/customColorsExtension.dart';
import 'package:eschool_saas_staff/ui/widgets/customTextContainer.dart';
import 'package:eschool_saas_staff/utils/constants.dart';
import 'package:eschool_saas_staff/utils/labelKeys.dart';
import 'package:eschool_saas_staff/utils/utils.dart';
import 'package:flutter/material.dart';

class StudentAttendanceItemContainer extends StatefulWidget {
  final bool showStatusPicker;
  final bool isPresent;
  final StudentDetails studentDetails;
  final Function(StudentAttendanceStatus status)? onChangeAttendance;
  const StudentAttendanceItemContainer({
    super.key,
    required this.studentDetails,
    this.showStatusPicker = false,
    required this.isPresent,
    this.onChangeAttendance,
  });

  @override
  State<StudentAttendanceItemContainer> createState() =>
      _StudentAttendanceItemContainerState();
}

class _StudentAttendanceItemContainerState
    extends State<StudentAttendanceItemContainer> {
  late StudentAttendanceStatus selectedValue = widget.isPresent
      ? StudentAttendanceStatus.present
      : StudentAttendanceStatus.absent;

  _buildStatusPicker(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: selectedValue == StudentAttendanceStatus.absent
            ? Theme.of(context)
                .extension<CustomColors>()!
                .totalStudentOverviewBackgroundColor!
                .withOpacity(0.1)
            : Theme.of(context)
                .extension<CustomColors>()!
                .totalStaffOverviewBackgroundColor!
                .withOpacity(0.1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: DropdownButton<StudentAttendanceStatus>(
        items: [
          DropdownMenuItem(
            value: StudentAttendanceStatus.present,
            child: Text(
              Utils.getTranslatedLabel(presentKey),
              style: TextStyle(
                color: Theme.of(context)
                    .extension<CustomColors>()!
                    .totalStaffOverviewBackgroundColor!,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          DropdownMenuItem(
            value: StudentAttendanceStatus.absent,
            child: Text(
              Utils.getTranslatedLabel(absentKey),
              style: TextStyle(
                color: Theme.of(context)
                    .extension<CustomColors>()!
                    .totalStudentOverviewBackgroundColor!,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        value: selectedValue,
        onChanged: (value) {
          if (value != null) {
            setState(() {
              selectedValue = value;
            });
            if (widget.onChangeAttendance != null) {
              widget.onChangeAttendance!(selectedValue);
            }
          }
        },
        underline: const SizedBox(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final border = BorderSide(color: Theme.of(context).colorScheme.tertiary);
    return Container(
      width: MediaQuery.of(context).size.width,
      height: 65,
      padding: EdgeInsets.symmetric(
          horizontal: appContentHorizontalPadding, vertical: 10),
      decoration: BoxDecoration(
          border: Border(left: border, bottom: border, right: border)),
      child: LayoutBuilder(builder: (context, boxConstraints) {
        return Row(
          children: [
            SizedBox(
              width: boxConstraints.maxWidth * (0.175),
              child: CustomTextContainer(
                  textKey:
                      widget.studentDetails.student?.rollNumber?.toString() ??
                          "-"),
            ),
            Expanded(
              child: CustomTextContainer(
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textKey: (widget.studentDetails.fullName ?? ""),
                style: const TextStyle(
                    fontSize: 15.0, fontWeight: FontWeight.w600),
              ),
            ),
            if (widget.showStatusPicker) ...[
              _buildStatusPicker(context),
            ] else ...[
              Container(
                height: 40,
                width: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: widget.isPresent
                        ? Theme.of(context)
                            .extension<CustomColors>()!
                            .totalStaffOverviewBackgroundColor!
                            .withOpacity(0.1)
                        : Theme.of(context)
                            .extension<CustomColors>()!
                            .totalStudentOverviewBackgroundColor!
                            .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(5)),
                child: CustomTextContainer(
                  textKey: widget.isPresent ? "P" : "A",
                  style: TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.w600,
                    color: widget.isPresent
                        ? Theme.of(context)
                            .extension<CustomColors>()!
                            .totalStaffOverviewBackgroundColor
                        : Theme.of(context)
                            .extension<CustomColors>()!
                            .totalStudentOverviewBackgroundColor!,
                  ),
                ),
              ),
            ],
          ],
        );
      }),
    );
  }
}
