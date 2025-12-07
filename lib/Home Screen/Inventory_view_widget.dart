import 'package:flutter/material.dart';
import '../Head Screen/Approve_result.dart';
import '../Head Screen/donation_analytics_screen.dart';
import '../Head Screen/re-enrollment.dart';
import '../l10n/app_localizations.dart';

class DashboardAccessPill extends StatelessWidget {
  final VoidCallback onTap;
  final String? title;
  final String? subtitle;
  final IconData icon;

  const DashboardAccessPill({
    super.key,
    required this.onTap,
    this.title,
    this.subtitle,
    this.icon = Icons.bar_chart_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    final String finalTitle =
        title ?? AppLocalizations.of(context)!.expensesDashboard;
    final String finalSubtitle =
        subtitle ?? AppLocalizations.of(context)!.getDetailedExpenses;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(100),
          splashColor: Colors.red.withOpacity(0.1),
          highlightColor: Colors.red.withOpacity(0.05),
          child: Container(
            height: 70,
            width: screenWidth * 0.95,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white, Colors.grey.shade100],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: Colors.grey.shade200, width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  height: 50,
                  width: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red.withOpacity(0.1),
                  ),
                  child: Icon(icon, color: Colors.redAccent.shade200, size: 28),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        finalTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        finalSubtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.redAccent.shade100,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class KitchenManagementCard extends StatelessWidget {
  final VoidCallback onTap;
  final String? title;
  final String? subtitle;
  final String iconPath;

  const KitchenManagementCard({
    super.key,
    required this.onTap,
    this.title,
    this.subtitle,
    this.iconPath = 'assets/images/kitchen.png',
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    const cardHeight = 80.0;

    final String finalTitle =
        title ?? AppLocalizations.of(context)!.kitchenManagement;
    final String finalSubtitle =
        subtitle ?? AppLocalizations.of(context)!.manageIngredients;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: Colors.red.withOpacity(0.1),
          highlightColor: Colors.red.withOpacity(0.05),
          child: Container(
            height: cardHeight,
            width: screenWidth * 0.95,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white, Colors.grey.shade50],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  height: 50,
                  width: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red.withOpacity(0.08),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Image.asset(
                      iconPath,
                      fit: BoxFit.contain,
                      color: Colors.redAccent.shade200,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        finalTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        finalSubtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 35,
                  width: 35,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.redAccent.shade100,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              AppLocalizations.of(context)!.managementTools,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                title: AppLocalizations.of(context)!.certificateIssue,
                subtitle: AppLocalizations.of(context)!.manageStudentData,
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
                title: AppLocalizations.of(context)!.charityManages,
                subtitle: AppLocalizations.of(context)!.manageCharityDonation,
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
                title: AppLocalizations.of(context)!.reEnrollment,
                subtitle: AppLocalizations.of(context)!.reEnrollProcess,
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
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
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
                        fontWeight: FontWeight.bold,
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
