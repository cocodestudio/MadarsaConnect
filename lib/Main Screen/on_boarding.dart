import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../Data/data.dart';
import '../Login & Signup Screen/loginpage.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';

class Onboarding extends StatefulWidget {
  const Onboarding({super.key});
  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  int currentIndex = 0;
  late PageController _controller;

  @override
  void initState() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
    _controller = PageController(initialPage: 0);
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _getTitle(BuildContext context, int index) {
    if (index == 0) return AppLocalizations.of(context)!.onboardingTitle1;
    if (index == 1) return AppLocalizations.of(context)!.onboardingTitle2;
    return AppLocalizations.of(context)!.onboardingTitle3;
  }

  String _getDescription(BuildContext context, int index) {
    if (index == 0) return AppLocalizations.of(context)!.onboardingDesc1;
    if (index == 1) return AppLocalizations.of(context)!.onboardingDesc2;
    return AppLocalizations.of(context)!.onboardingDesc3;
  }

  String _getButtonText(BuildContext context, int index) {
    if (index == 0) return AppLocalizations.of(context)!.welcomeBtn;
    if (index == 1) return AppLocalizations.of(context)!.learnMoreBtn;
    return AppLocalizations.of(context)!.getStartedBtn;
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Select Language",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 16),
                _buildLanguageOption(context, "English", "en"),
                const Divider(),
                _buildLanguageOption(context, "हिंदी (Hindi)", "hi"),
                const Divider(),
                _buildLanguageOption(context, "اردو (Urdu)", "ur"),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLanguageOption(BuildContext context, String label, String code) {
    return InkWell(
      onTap: () {
        Provider.of<LanguageProvider>(
          context,
          listen: false,
        ).changeLocale(code);
        Navigator.pop(context);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
            if (Localizations.localeOf(context).languageCode == code)
              const Icon(Icons.check_circle, color: Colors.redAccent, size: 20),
          ],
        ),
      ),
    );
  }

  String _getCurrentLanguageName(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    if (code == 'hi') return 'हिंदी';
    if (code == 'ur') return 'اردو';
    return 'English';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: true,
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: PageView.builder(
                itemCount: contents.length,
                controller: _controller,
                onPageChanged: (value) {
                  setState(() {
                    currentIndex = value;
                  });
                },
                itemBuilder: (context, index) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(),
                      AnimatedOpacity(
                        opacity: currentIndex == index ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 500),
                        child: Image.asset(
                          contents[index].image,
                          width: contents[index].width,
                          height: contents[index].height,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _getTitle(context, index),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: screenWidth * 0.07,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 15),
                      SizedBox(
                        width: screenWidth * 0.8,
                        child: Text(
                          _getDescription(context, index),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 14.0,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),

                  // --- LANGUAGE SELECTOR BUTTON ADDED HERE ---
                  GestureDetector(
                    onTap: () => _showLanguageDialog(context),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.language,
                            size: 20,
                            color: Colors.black54,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _getCurrentLanguageName(context),
                            style: const TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_drop_down,
                            size: 20,
                            color: Colors.black54,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // -------------------------------------------
                  ElevatedButton(
                    onPressed: () async {
                      if (currentIndex == contents.length - 1) {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('onBoardingShown', true);
                        if (!mounted) return;
                        Navigator.of(context).pushReplacement(
                          PageRouteBuilder(
                            pageBuilder:
                                (context, animation, secondaryAnimation) =>
                                    LoginPage(),
                            transitionsBuilder: (
                              context,
                              animation,
                              secondaryAnimation,
                              child,
                            ) {
                              var curve = CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeInCirc,
                              );
                              return ScaleTransition(
                                scale: curve,
                                child: child,
                              );
                            },
                          ),
                        );
                      } else {
                        _controller.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeIn,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.25,
                        vertical: screenHeight * 0.015,
                      ),
                      child: Text(
                        _getButtonText(context, currentIndex),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      contents.length,
                      (index) => buildDot(index, context),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  AnimatedContainer buildDot(int index, BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      height: screenHeight * 0.007,
      width: currentIndex == index ? screenWidth * 0.05 : screenWidth * 0.015,
      margin: const EdgeInsets.only(right: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: currentIndex == index ? Colors.black : Colors.grey,
      ),
    );
  }
}
