import 'package:eschool_saas_staff/app/routes.dart';
import 'package:eschool_saas_staff/cubits/homeScreenDataCubit.dart';
import 'package:eschool_saas_staff/ui/screens/home/widgets/homeContainer/widgets/contentTitleWithViewmoreButton.dart';
import 'package:eschool_saas_staff/ui/widgets/customTextContainer.dart';

import 'package:eschool_saas_staff/ui/widgets/leaveDetailsContainer.dart';
import 'package:eschool_saas_staff/utils/constants.dart';
import 'package:eschool_saas_staff/utils/labelKeys.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get/route_manager.dart';

class LeavesContainer extends StatelessWidget {
  const LeavesContainer({super.key});

  @override
  Widget build(BuildContext context) {
    final todaysLeave = context.read<HomeScreenDataCubit>().getTodayLeaves();
    return Container(
      margin: EdgeInsets.symmetric(
          horizontal: appContentHorizontalPadding,
          vertical: appContentHorizontalPadding),
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(2.5)),
      padding: EdgeInsets.symmetric(vertical: appContentHorizontalPadding),
      child: Column(
        children: [
          const SizedBox(
            height: 15,
          ),
          ContentTitleWithViewMoreButton(
            showViewMoreButton: true,
            contentTitleKey: leavesKey,
            viewMoreOnTap: () {
              Get.toNamed(Routes.generalLeavesScreen);
            },
          ),
          todaysLeave.isEmpty
              ? Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: appContentHorizontalPadding),
                  child: const CustomTextContainer(
                      textKey: everyoneIsPresentTodayKey),
                )
              : Column(
                  children: [
                    const SizedBox(
                      height: 15,
                    ),
                    LeaveDetailsContainer(
                      leaveDetails: todaysLeave.first,
                    ),
                    const SizedBox(
                      height: 15,
                    ),
                    todaysLeave.length > 2
                        ? LeaveDetailsContainer(leaveDetails: todaysLeave[1])
                        : const SizedBox(),
                  ],
                )
        ],
      ),
    );
  }
}
