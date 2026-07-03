class GifData {
  final String id;
  final String bodyPart;
  final String title;
  final String gifUrl;

  GifData({
    required this.id,
    required this.bodyPart,
    required this.title,
    required this.gifUrl,
  });

  factory GifData.fromJson(Map<String, dynamic> json) => GifData(
        id: json['id'] ?? '',
        bodyPart: json['body_part'] ?? '',
        title: json['title'] ?? '',
        gifUrl: json['gif_url'] ?? '',
      );
}
