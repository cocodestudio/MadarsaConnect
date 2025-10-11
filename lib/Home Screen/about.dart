import 'package:flutter/material.dart';
import 'package:madarsaConnect/Data/loader.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  bool _isImageLoading = true;
  bool _didPrecache = false;
  final String _founderImageUrl =
      'https://firebasestorage.googleapis.com/v0/b/madarsaconnect-c96d3.firebasestorage.app/o/WhatsApp%20Image%202025-10-03%20at%2019.32.43_52b1d178.jpg?alt=media&token=142af530-fa37-4771-ba00-d81e3a5b2135';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didPrecache) {
      precacheImage(NetworkImage(_founderImageUrl), context)
          .then((_) {
            if (mounted) {
              setState(() {
                _isImageLoading = false;
              });
            }
          })
          .catchError((_) {
            if (mounted) {
              setState(() {
                _isImageLoading = false;
              });
            }
          });
      _didPrecache = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.grey.withOpacity(0.2),
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 26),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'About Us',
          style: TextStyle(
            fontSize: 20,
            fontFamily: 'Gilroy-Bold',
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body:
          _isImageLoading
              ? const Center(child: GradientSpinner())
              : SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    _buildSection(
                      context,
                      'About the App',
                      'Madarsa Connect is a comprehensive platform designed to connect Madarsas, teachers, students, and parents. Its purpose is to streamline administrative tasks, enhance educational performance, and foster a strong community.',
                      icon: Icons.info_outline,
                    ),
                    const SizedBox(height: 30),
                    _buildFounderSection(
                      context,
                      'Founder',
                      'Moh Abuzar',
                      'A visionary who founded Madarsa Connect with a passion for integrating education with technology. He believes that with the right tools, education can be revolutionized.',
                      _founderImageUrl,
                    ),
                    const SizedBox(height: 30),
                    _buildSection(
                      context,
                      'About the Company',
                      'Madarsa Connect is developed by CoCode Studio. We are a technology company that specializes in creating solutions with human-centric design and robust engineering. Our mission is to bring meaningful and positive change to the world.',
                      icon: Icons.business_outlined,
                    ),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    String content, {
    IconData? icon,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(screenWidth * 0.05),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: Colors.blueAccent),
                const SizedBox(width: 8),
              ],
              Text(
                title,
                // ✅ FIX: Replaced GoogleFonts with your custom font
                style: const TextStyle(
                  fontFamily: 'Gilroy-Bold',
                  fontSize: 18,
                  color: Color(0xFF1A237E),
                ),
              ),
            ],
          ),
          const Divider(height: 24, thickness: 1),
          Text(
            content,
            // ✅ FIX: Replaced GoogleFonts with your custom font
            style: const TextStyle(
              fontFamily: 'Gilroy-Regular',
              fontSize: 14,
              height: 1.5,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFounderSection(
    BuildContext context,
    String title,
    String name,
    String bio,
    String imageUrl,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(screenWidth * 0.05),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            // ✅ FIX: Replaced GoogleFonts with your custom font
            style: const TextStyle(
              fontFamily: 'Gilroy-Bold',
              fontSize: 18,
              color: Color(0xFF1A237E),
            ),
          ),
          const Divider(height: 24, thickness: 1),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipOval(
                child: Image.network(
                  imageUrl,
                  height: 100,
                  width: 100,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (context, error, stackTrace) =>
                          const Icon(Icons.person, size: 80),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      // ✅ FIX: Replaced GoogleFonts with your custom font
                      style: const TextStyle(
                        fontFamily: 'Gilroy-Bold',
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      bio,
                      // ✅ FIX: Replaced GoogleFonts with your custom font
                      style: const TextStyle(
                        fontFamily: 'Gilroy-Regular',
                        fontSize: 14,
                        height: 1.5,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
