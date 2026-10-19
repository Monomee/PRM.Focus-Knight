import 'dart:ui';

/// Where an image of [image] size lands inside [box] with `BoxFit.cover`, centered.
Rect coverRect(Size box, Size image) {
  final scale = box.width / image.width > box.height / image.height
      ? box.width / image.width
      : box.height / image.height;
  final w = image.width * scale, h = image.height * scale;
  return Rect.fromLTWH((box.width - w) / 2, (box.height - h) / 2, w, h);
}
