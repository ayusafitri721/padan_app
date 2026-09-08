import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

void showSuccessDialog(
  BuildContext context, {
  required String title,
  required String desc,
  VoidCallback? onOk,
}) {
  AwesomeDialog(
    context: context,
    customHeader: const _PadanLogoHeader(),
    title: title,
    desc: desc,
    btnOkText: 'Lanjut',
    btnOkColor: AppColors.primary,
    btnOkOnPress: onOk,
  ).show();
}

void showErrorDialog(
  BuildContext context, {
  required String title,
  required String desc,
}) {
  AwesomeDialog(
    context: context,
    customHeader: const _PadanLogoHeader(),
    title: title,
    desc: desc,
    btnOkText: 'Coba Lagi',
    btnOkColor: const Color(0xFFD32F2F),
    btnOkOnPress: () {},
  ).show();
}

class _PadanLogoHeader extends StatelessWidget {
  const _PadanLogoHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.restaurant,
        size: 48,
        color: AppColors.cream,
      ),
    );
  }
}