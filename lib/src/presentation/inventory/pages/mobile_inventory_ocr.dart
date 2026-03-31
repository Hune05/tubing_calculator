// lib/src/presentation/inventory/pages/mobile_inventory_ocr.dart

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart'; // 🚀 자르기 패키지
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  static final ImagePicker _picker = ImagePicker();
  static final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  /// ---------------------------------------------------------
  /// 🚀 기능 1: 라벨 전체 스캔 & AI 자동 분류 (새 자재 등록용)
  /// ---------------------------------------------------------
  static Future<Map<String, String>?> scanAndClassify(
    BuildContext context,
  ) async {
    try {
      // 1. 카메라로 사진 촬영
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 100, // 자르기를 위해 화질을 높임
      );

      if (image == null) return null;

      // 🚀 2. 사진 찍은 직후 '영역 자르기' 화면 실행
      CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: '라벨 전체 구역을 지정해주세요',
            toolbarColor: const Color(0xFF007580), // 마키타 틸 색상
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
            hideBottomControls: false,
          ),
          IOSUiSettings(title: '라벨 전체 구역을 지정해주세요'),
        ],
      );

      // 자르기를 취소하고 뒤로갔을 경우
      if (croppedFile == null) return null;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xFF007580)),
        ),
      );

      // 3. 자른 이미지(croppedFile)를 ML Kit에 전달
      final InputImage inputImage = InputImage.fromFilePath(croppedFile.path);
      final RecognizedText recognizedText = await _textRecognizer.processImage(
        inputImage,
      );

      if (context.mounted) Navigator.pop(context);

      if (recognizedText.text.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("인식된 글자가 없습니다. 범위를 다시 지정해주세요.")),
          );
        }
        return null;
      }

      String raw = recognizedText.text.toUpperCase();

      String material = "";
      if (raw.contains("316L"))
        material = "SS316L";
      else if (raw.contains("304"))
        material = "SS304";
      else if (raw.contains("MONEL"))
        material = "MONEL";
      else if (raw.contains("CARBON"))
        material = "CARBON";
      else if (raw.contains("TEFLON"))
        material = "TEFLON";

      String heatNo = "";
      RegExp heatRegex = RegExp(r'(?:HEAT|LOT|H/N|HT|NO)\.?[\s:]*([A-Z0-9]+)');
      var match = heatRegex.firstMatch(raw);
      if (match != null) {
        heatNo = match.group(1) ?? "";
      }

      String text = raw.replaceAll('\n', ' ').trim();
      text = text.replaceAll('L/2', '1/2');
      text = text.replaceAll('I/2', '1/2');
      text = text.replaceAll('|/2', '1/2');
      text = text.replaceAll('L/4', '1/4');
      text = text.replaceAll('I/4', '1/4');
      text = text.replaceAll('3/S', '3/8');
      text = text.replaceAll('S5316', 'SS316');
      text = text.replaceAll('55316', 'SS316');
      text = text.replaceAll('S5304', 'SS304');
      text = text.replaceAll('O.D', 'OD');

      text = text.replaceAll(RegExp(r'[^A-Z0-9\-\/\.\s]'), '');
      String finalName = text.replaceAll(RegExp(r'\s+'), ' ').trim();

      return {"name": finalName, "material": material, "heatNo": heatNo};
    } catch (e) {
      if (context.mounted && Navigator.canPop(context)) Navigator.pop(context);
      debugPrint("OCR 스캔 에러: $e");
      return null;
    }
  }

  /// ---------------------------------------------------------
  /// 🚀 기능 2: 단일 항목 단순 스캔 (히트넘버 등 개별 입력용)
  /// ---------------------------------------------------------
  static Future<String?> scanLabelText(BuildContext context) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 100,
      );

      if (image == null) return null;

      // 🚀 핵심 수정 포인트: 비율을 5:1로 강제하여 아주 좁고 긴 직사각형이 기본으로 뜨게 만듭니다.
      CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        aspectRatio: const CropAspectRatio(ratioX: 5, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: '해당 글자 한 줄만 좁게 잘라주세요',
            toolbarColor: const Color(0xFF007580),
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.ratio16x9,
            lockAspectRatio: false, // 사용자가 모서리를 당겨서 미세 조정하는 것은 허용
          ),
          IOSUiSettings(
            title: '해당 글자 한 줄만 좁게 잘라주세요',
            aspectRatioLockEnabled: false,
          ),
        ],
      );

      if (croppedFile == null) return null;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xFF007580)),
        ),
      );

      final InputImage inputImage = InputImage.fromFilePath(croppedFile.path);
      final RecognizedText recognizedText = await _textRecognizer.processImage(
        inputImage,
      );

      if (context.mounted) Navigator.pop(context);

      if (recognizedText.text.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("인식된 글자가 없습니다. 범위를 다시 지정해주세요.")),
          );
        }
        return null;
      }

      String text = recognizedText.text
          .replaceAll('\n', ' ')
          .trim()
          .toUpperCase();

      text = text.replaceAll('L/2', '1/2');
      text = text.replaceAll('I/2', '1/2');
      text = text.replaceAll('|/2', '1/2');
      text = text.replaceAll('L/4', '1/4');
      text = text.replaceAll('I/4', '1/4');
      text = text.replaceAll('3/S', '3/8');
      text = text.replaceAll('S5316', 'SS316');
      text = text.replaceAll('55316', 'SS316');
      text = text.replaceAll('S5304', 'SS304');
      text = text.replaceAll('O.D', 'OD');

      text = text.replaceAll(RegExp(r'[^A-Z0-9\-\/\.\s]'), '');
      String finalResult = text.replaceAll(RegExp(r'\s+'), ' ').trim();

      return finalResult;
    } catch (e) {
      if (context.mounted && Navigator.canPop(context)) Navigator.pop(context);
      debugPrint("OCR 스캔 에러: $e");
      return null;
    }
  }

  static void dispose() {
    _textRecognizer.close();
  }
}
