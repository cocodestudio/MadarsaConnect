import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../Data/loader.dart';
import '../l10n/app_localizations.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  bool _isLoading = true;
  String _appVersion = '';
  String _buildNumber = '';
  final String _founderImageUrl =
      'https://firebasestorage.googleapis.com/v0/b/madarsaconnect-c96d3.firebasestorage.app/o/WhatsApp%20Image%202025-10-03%20at%2019.32.43_52b1d178.jpg?alt=media&token=142af530-fa37-4771-ba00-d81e3a5b2135';

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        await precacheImage(NetworkImage(_founderImageUrl), context);
        setState(() {
          _appVersion = packageInfo.version;
          _buildNumber = packageInfo.buildNumber;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _appVersion = 'Unknown';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.grey.withOpacity(0.1),
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 26, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppLocalizations.of(context)!.aboutUs,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold, // Replaced Gilroy-Bold
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body:
          _isLoading
              ? const Center(child: GradientSpinner())
              : _buildAnimatedListView(),
    );
  }

  Widget _buildAnimatedListView() {
    final widgets = [
      _buildSectionCard(
        icon: Icons.rocket_launch_rounded,
        title: AppLocalizations.of(context)!.ourMission,
        content: AppLocalizations.of(context)!.missionDescription,
      ),
      _buildFounderCard(),
      _buildSectionCard(
        icon: Icons.business_center_rounded,
        title: AppLocalizations.of(context)!.developedBy,
        content: AppLocalizations.of(context)!.developedByDesc,
      ),
      _buildFooter(),
    ];

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      itemCount: widgets.length,
      separatorBuilder: (context, index) => const SizedBox(height: 20),
      itemBuilder: (context, index) {
        return widgets[index]
            .animate()
            .fadeIn(delay: (150 * index).ms, duration: 500.ms)
            .slideY(begin: 0.2, duration: 400.ms, curve: Curves.easeOut);
      },
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.redAccent, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold, // Replaced Gilroy-Bold
                    fontSize: 18,
                    color: Color(0xFF333333),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24, thickness: 0.5),
          Text(
            content,
            style: const TextStyle(
              // Replaced Gilroy-Regular
              fontSize: 15,
              height: 1.6,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFounderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.redAccent.shade100, Colors.redAccent.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.redAccent.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 45,
            backgroundColor: Colors.white,
            child: CircleAvatar(
              radius: 42,
              backgroundImage: NetworkImage(_founderImageUrl),
              onBackgroundImageError: (_, __) {},
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Moh Abuzar', // Name usually stays same, or you can localize it
                  style: TextStyle(
                    fontWeight: FontWeight.bold, // Replaced Gilroy-Bold
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppLocalizations.of(context)!.founderVisionary,
                  style: const TextStyle(
                    // Replaced Gilroy-Regular
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Text(
          AppLocalizations.of(context)!.connectWithUs,
          style: const TextStyle(
            fontWeight: FontWeight.w600, // Replaced Gilroy-SemiBold
            fontSize: 16,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSocialIcon(
              Icons.language,
              () => _launchURL('https://madarsaconnect.xyz'),
            ),
            const SizedBox(width: 20),
            _buildSocialIcon(
              Icons.work_outline,
              () => _launchURL(
                'https://www.linkedin.com/in/moh-abuzar-6a880b30b?utm_source=share&utm_campaign=share_via&utm_content=profile&utm_medium=android_app',
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          '${AppLocalizations.of(context)!.version} $_appVersion ($_buildNumber)',
          style: TextStyle(
            // Replaced Gilroy-Regular
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildSocialIcon(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Icon(icon, color: Colors.black54, size: 24),
      ),
    );
  }

  void _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {}
  }
}
