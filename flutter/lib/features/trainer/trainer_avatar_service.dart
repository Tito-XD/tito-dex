import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../theme/tito_colors.dart';

/// Pick a photo and crop to a square trainer avatar.
abstract final class TrainerAvatarService {
  static final _picker = ImagePicker();

  static Future<String?> pickAndCropSquare() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
      );
      if (picked == null) {
        return null;
      }

      if (kIsWeb) {
        return picked.path;
      }

      final cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 88,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: '裁切头像',
            toolbarColor: TitoColors.deepBlue,
            toolbarWidgetColor: TitoColors.card,
            activeControlsWidgetColor: TitoColors.softYellow,
            statusBarColor: TitoColors.deepBlue,
            backgroundColor: TitoColors.deepBlue,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            hideBottomControls: false,
          ),
          IOSUiSettings(
            title: '裁切头像',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );

      if (cropped == null) {
        return null;
      }

      final dir = await getApplicationDocumentsDirectory();
      final out = File('${dir.path}/trainer_avatar.jpg');
      await out.writeAsBytes(await cropped.readAsBytes(), flush: true);
      return out.path;
    } catch (error, stackTrace) {
      debugPrint('TrainerAvatarService: $error');
      debugPrint('$stackTrace');
      rethrow;
    }
  }
}
