import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final inputPath = 'assets/images/logo/logo_default.png';
  final outputPath = 'assets/images/logo/logo_default_padded.png';

  final file = File(inputPath);
  if (!file.existsSync()) {
    print('File not found: $inputPath');
    return;
  }

  final original = img.decodePng(file.readAsBytesSync());
  if (original == null) {
    print('Failed to decode PNG');
    return;
  }

  // Android Adaptive Icons recommend the logo to be within the inner 72dp of a 108dp icon.
  // This means the logo should take up exactly 66.6% of the canvas.
  // We will make the canvas 1.8x the original size.
  final newWidth = (original.width * 1.8).round();
  final newHeight = (original.height * 1.8).round();

  final padded = img.Image(width: newWidth, height: newHeight, numChannels: 4);

  // Fill with transparent
  img.fill(padded, color: img.ColorRgba8(0, 0, 0, 0));

  // Draw original in center
  final dstX = (newWidth - original.width) ~/ 2;
  final dstY = (newHeight - original.height) ~/ 2;
  img.compositeImage(padded, original, dstX: dstX, dstY: dstY);

  File(outputPath).writeAsBytesSync(img.encodePng(padded));
  print('Successfully generated padded icon: $outputPath');
}
