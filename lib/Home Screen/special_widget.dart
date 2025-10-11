import 'package:flutter/material.dart';
import 'package:madarsaConnect/Head%20Screen/Approve_result.dart';
import 'package:madarsaConnect/Head%20Screen/donation_analytics_screen.dart';
import 'package:madarsaConnect/Head%20Screen/re-enrollment.dart';
import 'package:madarsaConnect/Head%20Screen/staff_panel.dart';

typedef SubscriptionCheckOnTap =
    void Function(BuildContext context, Widget destinationPage);

class ManagementSectionNew extends StatelessWidget {
  final String userRole;
  final String? headUid;
  final SubscriptionCheckOnTap onTap;

  const ManagementSectionNew({
    Key? key,
    required this.userRole,
    this.headUid,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade400, width: 0.4),
      ),
      padding: EdgeInsets.all(screenWidth * 0.02),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              'Management Tools',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'Gilroy-Bold',
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildModernManagementTile(
                context: context,
                imagePath: 'assets/images/certificate_issue.png',
                imageColor: Colors.redAccent.shade100,
                title: 'Certificate Issue',
                subtitle: 'Manage student data & analytics',
                onTap: () {
                  if (userRole == 'head' && headUid != null) {
                    this.onTap(context, ApproveMarksScreen(headUid: headUid!));
                  }
                },
              ),
              const SizedBox(width: 8),
              _buildModernManagementTile(
                context: context,
                imagePath: 'assets/images/charity.png',
                imageColor: Colors.redAccent.shade100,
                title: 'Charity Manages',
                subtitle: 'Manage charity donation payments',
                onTap: () {
                  if (userRole == 'head' && headUid != null) {
                    this.onTap(
                      context,
                      DonationAnalyticsScreen(headUid: headUid!),
                    );
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              _buildModernManagementTile(
                context: context,
                imagePath: 'assets/images/enroll.png',
                imageColor: Colors.redAccent.shade100,
                title: 'Re-Enrollment/Re-Admission', // Example title
                subtitle: 'Re-Enroll students or re-admission process',
                onTap: () {
                  if (userRole == 'head' && headUid != null) {
                    this.onTap(context, ReEnrollStudentScreen());
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModernManagementTile({
    required BuildContext context,
    required String imagePath,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? imageColor,
  }) {
    return Expanded(
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          highlightColor: Colors.grey.shade50,
          child: Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade300, width: 1.0),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset(
                  imagePath,
                  height: 48,
                  width: 48,
                  fit: BoxFit.contain,
                  color: imageColor,
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Gilroy-Bold',
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                    fontFamily: 'Gilroy-Regular',
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Yeh neeche wala function aapko delete nahi karna hai, usko waise hi rehne dein
Widget customSizedTile(
  String imagePath,
  String title, {
  double? size,
  VoidCallback? onTap,
}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final tileWidth = size ?? (MediaQuery.of(context).size.width - 48) / 3;
      final tileHeight = tileWidth * (160 / 110);

      return SizedBox(
        width: tileWidth,
        height: tileHeight,
        child: Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade300, width: 1.0),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            highlightColor: Colors.grey.shade50,
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontFamily: 'Gilroy-Bold',
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Image.asset(
                      imagePath,
                      height: tileHeight * 0.35,
                      width: tileWidth * 0.35,
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
