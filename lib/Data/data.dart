class UnbordingContent {
  String image;
  String title;
  String discription;
  double width;
  double height;

  UnbordingContent({
    required this.image,
    required this.title,
    required this.discription,
    required this.width,
    required this.height,
  });
}

List<UnbordingContent> contents = [
  UnbordingContent(
    title: 'Improvement',
    image: 'assets/images/index1.png',
    discription: "It will improve all your shortcomings and help you in everything you do.",
    width: 350,
    height: 350,
  ),
  UnbordingContent(
      title: 'Digitally Management',
      image: 'assets/images/index2.png',
      discription: "All your personal work and Madarsa records will be maintained digitally.",
      width: 350,
      height: 350
  ),
  UnbordingContent(
    title: 'Everywhere Availability',
    image: 'assets/images/index3.png',
    discription: "You will find this all over India, and every Madarsa will be able to benefit from it.",
    width: 320,
    height: 320,
  ),
];




