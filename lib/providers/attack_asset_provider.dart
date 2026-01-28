import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

class AttackAssetState {
  final XFile? selectedImage;
  final Uint8List? imageBytes;

  AttackAssetState({this.selectedImage, this.imageBytes});

  AttackAssetState copyWith({XFile? selectedImage, Uint8List? imageBytes}) {
    return AttackAssetState(
      selectedImage: selectedImage ?? this.selectedImage,
      imageBytes: imageBytes ?? this.imageBytes,
    );
  }
}

class AttackAssetNotifier extends Notifier<AttackAssetState> {
  final ImagePicker _picker = ImagePicker();

  @override
  AttackAssetState build() {
    return AttackAssetState();
  }

  Future<void> pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final bytes = await image.readAsBytes();
        state = state.copyWith(selectedImage: image, imageBytes: bytes);
      }
    } catch (e) {
      print("[AttackAsset] Error picking image: $e");
    }
  }

  void clearImage() {
    state = AttackAssetState();
  }
}

final attackAssetProvider =
    NotifierProvider<AttackAssetNotifier, AttackAssetState>(() {
  return AttackAssetNotifier();
});
