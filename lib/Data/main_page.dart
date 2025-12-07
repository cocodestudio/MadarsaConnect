import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../Faculty Screen/donation_screen.dart';
import '../Head Screen/madarsa_management_view.dart';
import '../Home Screen/Inventory_view_widget.dart';
import '../Home Screen/feed_screen.dart';
import '../Home Screen/home_screen.dart';
import '../Home Screen/kitchen.dart';
import '../Home Screen/notify_screen.dart';
import '../Home Screen/pending_payment.dart';
import '../Home Screen/profile_screen.dart';
import '../Home Screen/search_animation.dart';
import '../Home Screen/search_screen.dart';
import '../Home Screen/subscription_screen.dart';
import '../Home Screen/support_screen.dart';
import '../Home Screen/upload_screen.dart';
import '../l10n/app_localizations.dart';
import 'dynamic_popup.dart';

enum SubscriptionStatus {
  checking,
  approved,
  pending,
  notSubscribed,
  notApplicable,
}

class MainPage extends StatefulWidget {
  final String? userRole;
  const MainPage({super.key, this.userRole});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final PageController _pageController = PageController(initialPage: 0);
  final PageController _carouselController = PageController();

  int _currentIndex = 0;
  Timer? _carouselTimer;
  DateTime? _lastPressedAt;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late Future<List<String>> _carouselImagesFuture;

  @override
  void initState() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
    super.initState();
    _askAllPermissions();
    _carouselImagesFuture = _loadCarouselImages();
    _carouselImagesFuture.then((images) {
      if (images.isNotEmpty && mounted) {
        _startCarouselTimer();
      }
    });
    _checkForUpdate();
    MobileAds.instance.initialize();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _carouselController.dispose();
    _carouselTimer?.cancel();
    super.dispose();
  }

  void _startCarouselTimer() {
    _carouselTimer?.cancel();

    _carouselTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!_carouselController.hasClients) return;

      int nextPage = (_carouselController.page?.round() ?? 0) + 1;
      _carouselController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  Future<List<String>> _loadCarouselImages() async {
    final List<String> allUrls = [];
    final List<String> categories = ["home", "events", "promotions"];

    try {
      for (var category in categories) {
        final docSnapshot =
            await _firestore
                .collection('app_data')
                .doc('carousel_$category')
                .get();

        if (docSnapshot.exists) {
          final data = docSnapshot.data();
          if (data != null && data.containsKey('imageUrls')) {
            final urls = List<String>.from(data['imageUrls']);
            allUrls.addAll(urls);
          }
        }
      }
      return allUrls;
    } catch (e) {
      debugPrint('Error loading carousel images: $e');
      return [];
    }
  }

  Future<void> _checkForUpdate() async {
    if (Platform.isAndroid) {
      try {
        AppUpdateInfo updateInfo = await InAppUpdate.checkForUpdate();
        if (updateInfo.updateAvailability ==
            UpdateAvailability.updateAvailable) {
          await InAppUpdate.performImmediateUpdate();
        }
      } catch (e) {
        debugPrint("Error checking for update: $e");
      }
    }
  }

  Future<void> _askAllPermissions() async {
    try {
      final camera = await Permission.camera.request();
      final photos = await Permission.photos.request();
      final storage = await Permission.storage.request();
      final notification = await Permission.notification.request();

      if (camera.isPermanentlyDenied ||
          photos.isPermanentlyDenied ||
          storage.isPermanentlyDenied ||
          notification.isPermanentlyDenied) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder:
              (ctx) => AlertDialog(
                title: Text(AppLocalizations.of(ctx)!.permissionsRequired),
                content: Text(
                  AppLocalizations.of(ctx)!.enablePermissionsFromSettings,
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(AppLocalizations.of(ctx)!.cancel),
                  ),
                  TextButton(
                    onPressed: () {
                      openAppSettings();
                      Navigator.of(ctx).pop();
                    },
                    child: Text(AppLocalizations.of(ctx)!.openSettings),
                  ),
                ],
              ),
        );
      }
    } catch (e) {
      debugPrint('Permission request failed: $e');
    }
  }

  void _onItemTapped(int index) {
    if (index == 2) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => const UploadScreen(),
      );
    } else {
      if (!mounted) return;
      setState(() {
        _currentIndex = index;
      });

      if (_pageController.hasClients) {
        _pageController.jumpToPage(index);
      }
    }
  }

  void _checkSubscriptionAndNavigate({
    required BuildContext context,
    required Widget subscribedPage,
  }) {
    final profileProvider = context.read<ProfileProvider>();
    switch (profileProvider.subscriptionStatus) {
      case SubscriptionStatus.approved:
      case SubscriptionStatus.notApplicable:
        navigateWithPremiumTransition(context, subscribedPage);
        break;
      case SubscriptionStatus.pending:
        navigateWithPremiumTransition(context, const PendingScreen());
        break;
      case SubscriptionStatus.notSubscribed:
        navigateWithPremiumTransition(context, const SubscriptionScreen());
        break;
      case SubscriptionStatus.checking:
        CustomPopup.show(
          context,
          AppLocalizations.of(context)!.verifyingStatus,
        );
        break;
    }
  }

  Widget _profileAvatar(double screenHeight, String? profileUrl) {
    if (profileUrl != null && profileUrl.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: profileUrl,
          width: screenHeight * 0.052,
          height: screenHeight * 0.052,
          fit: BoxFit.cover,
          placeholder:
              (context, url) => Container(
                width: screenHeight * 0.052,
                height: screenHeight * 0.052,
                color: Colors.grey.shade200,
              ),
          errorWidget: (context, error, stackTrace) {
            return Container(
              width: screenHeight * 0.052,
              height: screenHeight * 0.052,
              color: Colors.grey.shade200,
              child: SvgPicture.asset('assets/icons/users.svg'),
            );
          },
        ),
      );
    } else {
      return CircleAvatar(
        radius: screenHeight * 0.026,
        backgroundColor: Colors.grey.shade200,
        child: SvgPicture.asset(
          'assets/icons/users.svg',
          width: screenHeight * 0.027,
          height: screenHeight * 0.027,
          fit: BoxFit.contain,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    String firstName = (profileProvider.userName ?? '').split(' ').first;
    if (firstName.isNotEmpty) {
      firstName =
          '${firstName[0].toUpperCase()}${firstName.substring(1).toLowerCase()}';
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) {
        if (didPop) return;
        if (_currentIndex != 0) {
          if (!mounted) return;
          setState(() {
            _currentIndex = 0;
          });
          if (_pageController.hasClients) {
            _pageController.jumpToPage(0);
          }
        } else {
          final now = DateTime.now();
          final backButtonPressedOnce =
              _lastPressedAt != null &&
              now.difference(_lastPressedAt!) <= const Duration(seconds: 2);

          if (backButtonPressedOnce) {
            SystemNavigator.pop();
          } else {
            _lastPressedAt = now;
            if (!mounted) return;
          }
        }
      },
      child: Scaffold(
        extendBody: true,
        backgroundColor: Colors.white,
        body: SafeArea(
          top: true,
          bottom: false,
          child: Column(
            children: [
              if (_currentIndex == 0 && profileProvider.isRoleLoaded)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    screenWidth * 0.04,
                    3,
                    screenWidth * 0.02,
                    0,
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () async {
                          navigateWithPremiumTransition(
                            context,
                            ProfileScreen(
                              onProfileUpdated:
                                  () =>
                                      context
                                          .read<ProfileProvider>()
                                          .loadUserProfile(),
                            ),
                          );
                        },
                        child: _profileAvatar(
                          screenHeight,
                          profileProvider.profileUrl,
                        ),
                      ),
                      SizedBox(width: screenWidth * 0.02),
                      Text(
                        AppLocalizations.of(context)!.hiFirstName(firstName),
                        style: TextStyle(
                          fontSize: screenWidth * 0.042,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Builder(
                        builder:
                            (buttonContext) => IconButton(
                              icon: const Icon(
                                Icons.search,
                                color: Colors.black,
                              ),
                              onPressed: () {
                                final RenderBox renderBox =
                                    buttonContext.findRenderObject()
                                        as RenderBox;
                                final Offset globalPosition = renderBox
                                    .localToGlobal(Offset.zero);
                                final Offset center =
                                    globalPosition +
                                    Offset(
                                      renderBox.size.width / 2,
                                      renderBox.size.height / 2,
                                    );

                                Navigator.of(buttonContext).push(
                                  CircularRevealRoute(
                                    page: const SearchOverlayScreen(),
                                    center: center,
                                  ),
                                );
                              },
                            ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child:
                    profileProvider.isRoleLoaded
                        ? PageView(
                          controller: _pageController,
                          physics: const NeverScrollableScrollPhysics(),
                          onPageChanged: (index) {
                            if (!mounted) return;
                            setState(() {
                              _currentIndex = index;
                            });
                          },
                          children: [
                            Padding(
                              padding: EdgeInsets.all(screenWidth * 0.03),
                              child: SingleChildScrollView(
                                padding: EdgeInsets.only(
                                  bottom:
                                      MediaQuery.of(context).padding.bottom +
                                      kToolbarHeight,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    FutureBuilder<List<String>>(
                                      future: _carouselImagesFuture,
                                      builder: (context, snapshot) {
                                        if (snapshot.connectionState ==
                                            ConnectionState.waiting) {
                                          return Shimmer.fromColors(
                                            baseColor: Colors.grey.shade300,
                                            highlightColor:
                                                Colors.grey.shade100,
                                            child: Container(
                                              height: screenHeight * 0.2,
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(16.0),
                                              ),
                                            ),
                                          );
                                        } else if (snapshot.hasError) {
                                          return SizedBox(
                                            height: screenHeight * 0.2,
                                            child: Center(
                                              child: Text(
                                                AppLocalizations.of(
                                                  context,
                                                )!.errorLoadingImages,
                                                style: const TextStyle(
                                                  color: Colors.red,
                                                ),
                                              ),
                                            ),
                                          );
                                        } else if (snapshot.data == null ||
                                            snapshot.data!.isEmpty) {
                                          return SizedBox(
                                            height: screenHeight * 0.2,
                                            child: Center(
                                              child: Text(
                                                AppLocalizations.of(
                                                  context,
                                                )!.noImagesUploadedYet,
                                                style: const TextStyle(
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ),
                                          );
                                        } else {
                                          final cardImages = snapshot.data!;
                                          if (cardImages.length > 1 &&
                                              _carouselTimer == null) {
                                            _startCarouselTimer();
                                          }
                                          return Column(
                                            children: [
                                              SizedBox(
                                                height: screenHeight * 0.2,
                                                child: PageView.builder(
                                                  controller:
                                                      _carouselController,
                                                  itemBuilder: (
                                                    context,
                                                    index,
                                                  ) {
                                                    final actualItemCount =
                                                        cardImages.length;
                                                    if (actualItemCount == 0) {
                                                      return const SizedBox.shrink();
                                                    }
                                                    final loopedIndex =
                                                        index % actualItemCount;

                                                    return Padding(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 4.0,
                                                          ),
                                                      child: ClipRRect(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              16.0,
                                                            ),
                                                        child: CachedNetworkImage(
                                                          imageUrl:
                                                              cardImages[loopedIndex],
                                                          fit: BoxFit.cover,
                                                          placeholder:
                                                              (
                                                                context,
                                                                url,
                                                              ) => Shimmer.fromColors(
                                                                baseColor:
                                                                    Colors
                                                                        .grey
                                                                        .shade300,
                                                                highlightColor:
                                                                    Colors
                                                                        .grey
                                                                        .shade100,
                                                                child: Container(
                                                                  color:
                                                                      Colors
                                                                          .white,
                                                                ),
                                                              ),
                                                          errorWidget:
                                                              (
                                                                context,
                                                                url,
                                                                error,
                                                              ) => Container(
                                                                color:
                                                                    Colors
                                                                        .grey[200],
                                                                child: const Center(
                                                                  child: Icon(
                                                                    Icons
                                                                        .broken_image,
                                                                    color:
                                                                        Colors
                                                                            .grey,
                                                                  ),
                                                                ),
                                                              ),
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                              SizedBox(
                                                height: screenHeight * 0.018,
                                              ),
                                              Center(
                                                child: SmoothPageIndicator(
                                                  controller:
                                                      _carouselController,
                                                  count: cardImages.length,
                                                  effect: ExpandingDotsEffect(
                                                    activeDotColor:
                                                        Colors.black,
                                                    dotColor:
                                                        Colors.grey.shade300,
                                                    dotHeight:
                                                        screenWidth * 0.018,
                                                    dotWidth:
                                                        screenWidth * 0.013,
                                                    expansionFactor: 3,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        }
                                      },
                                    ),
                                    SizedBox(height: screenHeight * 0.010),
                                    if (profileProvider.isHead)
                                      DashboardAccessPill(
                                        onTap: () {
                                          navigateWithPremiumTransition(
                                            context,
                                            const DashboardViewScreen(),
                                          );
                                        },
                                      ),
                                    SizedBox(height: screenHeight * 0.007),
                                    DashboardCards(
                                      onTap: (
                                        BuildContext context,
                                        Widget destinationPage,
                                      ) {
                                        _checkSubscriptionAndNavigate(
                                          context: context,
                                          subscribedPage: destinationPage,
                                        );
                                      },
                                    ),
                                    SizedBox(height: screenHeight * 0.012),
                                    if (profileProvider.isHead ||
                                        profileProvider.isFaculty)
                                      KitchenManagementCard(
                                        onTap: () {
                                          navigateWithPremiumTransition(
                                            context,
                                            KitchenCalculatorScreen(),
                                          );
                                        },
                                      ),
                                    if (profileProvider.isFaculty ||
                                        profileProvider.isStudent)
                                      DonationCard(
                                        onTap: () {
                                          navigateWithPremiumTransition(
                                            context,
                                            const DonationScreen(),
                                          );
                                        },
                                      ),
                                    if (profileProvider.isHead)
                                      SubscriptionCard(
                                        onTap: () {
                                          navigateWithPremiumTransition(
                                            context,
                                            const SubscriptionScreen(),
                                          );
                                        },
                                      ),
                                    SizedBox(height: screenHeight * 0.018),
                                    if (profileProvider.isHead)
                                      AcademicAndToolsSection(
                                        headUid:
                                            FirebaseAuth
                                                .instance
                                                .currentUser!
                                                .uid,
                                        onTap: (
                                          BuildContext context,
                                          Widget destinationPage,
                                        ) {
                                          _checkSubscriptionAndNavigate(
                                            context: context,
                                            subscribedPage: destinationPage,
                                          );
                                        },
                                      ),
                                    SizedBox(height: screenHeight * 0.018),
                                    const Center(child: AdBannerCard()),
                                    SizedBox(height: screenHeight * 0.018),
                                    if (profileProvider.isHead)
                                      ManagementSectionNew(
                                        userRole: 'head',
                                        headUid:
                                            FirebaseAuth
                                                .instance
                                                .currentUser!
                                                .uid,
                                        onTap: (
                                          BuildContext context,
                                          Widget destinationPage,
                                        ) {
                                          _checkSubscriptionAndNavigate(
                                            context: context,
                                            subscribedPage: destinationPage,
                                          );
                                        },
                                      ),
                                    InviteCard(
                                      onTap: () {
                                        final String linkToShare =
                                            AppLocalizations.of(
                                              context,
                                            )!.appShareLink;
                                        final String message =
                                            AppLocalizations.of(
                                              context,
                                            )!.inviteMessage;
                                        Share.share('$message\n\n$linkToShare');
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const FeedScreen(),
                            const SizedBox(),
                            const SupportScreen(),
                            const NotifyScreen(),
                          ],
                        )
                        : const MainPageShimmer(),
              ),
            ],
          ),
        ),
        bottomNavigationBar: Builder(
          builder: (context) {
            final navBarHeight = screenHeight * 0.06;

            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFDDDDDD))),
              ),
              child: Padding(
                padding: const EdgeInsets.only(top: 5),
                child: SafeArea(
                  top: false,
                  bottom: true,
                  child: SizedBox(
                    height: navBarHeight,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _navIcon('assets/icons/home.svg', 0, screenHeight),
                        _navIcon('assets/icons/feed.svg', 1, screenHeight),
                        _centerUploadButton(navBarHeight),
                        _navIcon('assets/icons/support.svg', 3, screenHeight),
                        _navIcon(
                          'assets/icons/notification.svg',
                          4,
                          screenHeight,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _navIcon(String assetPath, int index, double screenHeight) {
    final bool isSelected = _currentIndex == index;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onItemTapped(index),
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SvgPicture.asset(
            assetPath,
            height: screenHeight * 0.028,
            colorFilter: ColorFilter.mode(
              isSelected ? Colors.black : Colors.grey,
              BlendMode.srcIn,
            ),
          ),
        ),
      ),
    );
  }

  Widget _centerUploadButton(double navBarHeight) {
    return SizedBox(
      width: navBarHeight * 1.2,
      height: navBarHeight * 1.2,
      child: FloatingActionButton(
        onPressed: () => _onItemTapped(2),
        backgroundColor: Colors.redAccent,
        elevation: 0,
        shape: const CircleBorder(),
        child: SvgPicture.asset(
          'assets/icons/upload.svg',
          width: navBarHeight * 0.6,
          height: navBarHeight * 0.6,
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        ),
      ),
    );
  }
}

class ProfileProvider with ChangeNotifier {
  String? _userName;
  String? _profileUrl;
  bool _isRoleLoaded = false;
  bool _isHead = false;
  bool _isFaculty = false;
  bool _isStudent = false;

  SubscriptionStatus _subscriptionStatus = SubscriptionStatus.checking;

  String? get userName => _userName;
  String? get profileUrl => _profileUrl;
  bool get isRoleLoaded => _isRoleLoaded;
  bool get isHead => _isHead;
  bool get isFaculty => _isFaculty;
  bool get isStudent => _isStudent;
  SubscriptionStatus get subscriptionStatus => _subscriptionStatus;

  ProfileProvider() {
    loadUserProfile();
  }

  Future<void> loadUserProfile() async {
    _isRoleLoaded = false;
    _subscriptionStatus = SubscriptionStatus.checking;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('cachedProfile');
    if (cached != null) {
      final map = jsonDecode(cached) as Map<String, dynamic>;
      _userName = map['fullName'] ?? '';
      _profileUrl = map['profilePictureUrl'] ?? '';
    }
    _isHead = prefs.getBool('isHead') ?? false;
    _isFaculty = prefs.getBool('isFaculty') ?? false;
    _isStudent = prefs.getBool('isStudent') ?? false;

    if (_isHead) {
      await _checkSubscriptionStatus();
    } else {
      _subscriptionStatus = SubscriptionStatus.notApplicable;
    }

    _isRoleLoaded = true;
    notifyListeners();
  }

  Future<void> _checkSubscriptionStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _subscriptionStatus = SubscriptionStatus.notSubscribed;
      return;
    }

    try {
      final approvedSnapshot =
          await FirebaseFirestore.instance
              .collection('subscriptionRequests')
              .where('userId', isEqualTo: user.uid)
              .where('status', isEqualTo: 'approved')
              .limit(1)
              .get();

      if (approvedSnapshot.docs.isNotEmpty) {
        _subscriptionStatus = SubscriptionStatus.approved;
        return;
      }

      final pendingSnapshot =
          await FirebaseFirestore.instance
              .collection('subscriptionRequests')
              .where('userId', isEqualTo: user.uid)
              .where('status', isEqualTo: 'pending')
              .limit(1)
              .get();

      if (pendingSnapshot.docs.isNotEmpty) {
        _subscriptionStatus = SubscriptionStatus.pending;
      } else {
        _subscriptionStatus = SubscriptionStatus.notSubscribed;
      }
    } catch (e) {
      debugPrint("Failed to check subscription: $e");
      _subscriptionStatus = SubscriptionStatus.notSubscribed;
    }
  }

  void resetState() {
    _userName = null;
    _profileUrl = null;
    _isRoleLoaded = false;
    _isHead = false;
    _isFaculty = false;
    _isStudent = false;
    _subscriptionStatus = SubscriptionStatus.checking;
    notifyListeners();
  }
}

class MainPageShimmer extends StatelessWidget {
  const MainPageShimmer({super.key});
  Widget _buildShimmerBlock({
    double? width,
    required double height,
    bool isCircle = false,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isCircle ? null : BorderRadius.circular(12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.02),
              child: Row(
                children: [
                  _buildShimmerBlock(
                    height: screenHeight * 0.052,
                    width: screenHeight * 0.052,
                    isCircle: true,
                  ),
                  const SizedBox(width: 12),
                  _buildShimmerBlock(height: 20, width: screenWidth * 0.3),
                  const Spacer(),
                  _buildShimmerBlock(height: 30, width: 30, isCircle: true),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildShimmerBlock(
              height: screenHeight * 0.2,
              width: double.infinity,
            ),
            const SizedBox(height: 16),
            Center(
              child: _buildShimmerBlock(height: 10, width: screenWidth * 0.2),
            ),
            const SizedBox(height: 24),
            _buildShimmerBlock(height: 80, width: double.infinity),
            const SizedBox(height: 12),
            _buildShimmerBlock(height: 80, width: double.infinity),
            const SizedBox(height: 12),
            _buildShimmerBlock(height: 80, width: double.infinity),
            const SizedBox(height: 12),
            _buildShimmerBlock(height: 80, width: double.infinity),
          ],
        ),
      ),
    );
  }
}

enum AdStatus { loading, loaded, failed }

class AdBannerCard extends StatefulWidget {
  const AdBannerCard({super.key});

  @override
  State<AdBannerCard> createState() => _AdBannerCardState();
}

class _AdBannerCardState extends State<AdBannerCard> {
  BannerAd? _bannerAd;
  AdStatus _adStatus = AdStatus.loading;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  void _loadAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-2465407468425782/8001108749',
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) {
            setState(() {
              _adStatus = AdStatus.loaded;
            });
          }
        },
        onAdFailedToLoad: (ad, err) {
          debugPrint('BannerAd failed to load: $err');
          ad.dispose();
          if (mounted) {
            setState(() {
              _adStatus = AdStatus.failed;
            });
          }
        },
      ),
    )..load();
  }

  Widget _buildAdContent() {
    switch (_adStatus) {
      case AdStatus.loaded:
        return AdWidget(ad: _bannerAd!);
      case AdStatus.failed:
        return GestureDetector(
          onTap: () {
            _launchURL('https://www.madarsaconnect.xyz');
          },
          child: Image.asset(
            'assets/images/banner.jpg',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
        );
      case AdStatus.loading:
      default:
        return Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Container(
            width: 320,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20.0),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 350,
      height: 50,
      child: Card(
        color: Colors.white,
        margin: EdgeInsets.zero,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
          side: BorderSide(color: Colors.grey.shade400, width: 0.8),
        ),
        child: _buildAdContent(),
      ),
    );
  }
}
