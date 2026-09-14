import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_client.dart';
import '../theme.dart';
import '../utils/errors.dart';
import '../utils/today_habits.dart';
import 'ui_bits.dart';

typedef CheckinSubmitter = Future<Map<String, dynamic>> Function({
  required String text,
  XFile? image,
});

/// 打卡凭证底栏：必须有文字或图片才会提交；失败时留在表单里。
class CheckinProofSheet extends StatefulWidget {
  const CheckinProofSheet({super.key, this.submitter});

  final CheckinSubmitter? submitter;

  @override
  State<CheckinProofSheet> createState() => _CheckinProofSheetState();
}

class _CheckinProofSheetState extends State<CheckinProofSheet> {
  final _textCtrl = TextEditingController();
  XFile? _image;
  Uint8List? _previewBytes;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 80);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _image = picked;
      _previewBytes = bytes;
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!hasCheckinProof(text: _textCtrl.text, hasImage: _image != null)) {
      setState(() => _error = '写一句或拍张照，圈子才能看见你完成了');
      return;
    }
    final text = _textCtrl.text.trim();
    if (text.length > 500) {
      setState(() => _error = '打卡内容不能超过 500 字');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final submit = widget.submitter ??
          ({required String text, XFile? image}) =>
              ApiClient.instance.completeCheckin(text: text, image: image);
      final res = await submit(text: _textCtrl.text, image: _image);
      if (!mounted) return;
      Navigator.pop(context, res['data'] as Map<String, dynamic>);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = formatError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: const Color(0xFFE0D6CC), borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('完成打卡', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text(
              '拍一张完成瞬间，或写一句给圈子看',
              style: TextStyle(color: Color(0xFF8A8078)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _textCtrl,
              maxLines: 3,
              maxLength: 500,
              enabled: !_submitting,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              decoration: const InputDecoration(hintText: '可选：写点完成感受'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _submitting ? null : () => _pick(ImageSource.gallery),
                  icon: const Icon(Icons.photo_outlined),
                  label: Text(_image == null ? '相册' : '已选图'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _submitting ? null : () => _pick(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('拍照'),
                ),
                if (_image != null) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _submitting
                        ? null
                        : () => setState(() {
                              _image = null;
                              _previewBytes = null;
                            }),
                    child: const Text('清除'),
                  ),
                ],
              ],
            ),
            if (_previewBytes != null) ...[
              const SizedBox(height: 12),
              LocalImagePreview(bytes: _previewBytes!),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Color(0xFFC0392B))),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('提交到社区'),
              ),
            ),
            TextButton(
              onPressed: _submitting ? null : () => Navigator.pop(context),
              child: const Center(child: Text('取消')),
            ),
          ],
        ),
      ),
    );
  }
}
