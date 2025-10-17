import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Data/data.dart';
import '../Login & Signup Screen/loginpage.dart';

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
      SystemUiOverlayStyle(
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
                        contents[index].title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: "Gilroy-Bold",
                          fontSize: screenWidth * 0.07,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 15),
                      SizedBox(
                        width: screenWidth * 0.8,
                        child: Text(
                          contents[index].discription,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 14.0,
                            fontFamily: "Gilroy-Regular",
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
                        currentIndex == 0
                            ? "Welcome"
                            : currentIndex == 1
                            ? "Learn More"
                            : "Get Started",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontFamily: 'Gilroy-Bold',
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
