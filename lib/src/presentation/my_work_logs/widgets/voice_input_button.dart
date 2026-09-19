import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

// 🚀 [음성 입력] 현장에서 손이 바쁠 때 말로 텍스트칸을 채운다. 기기의 음성 인식(구글
// 음성 서비스)을 쓰며, 듣는 동안 인식된 내용이 실시간으로 칸에 들어간다. 기존에 적어 둔
// 내용은 유지하고 뒤에 이어 붙인다.
class VoiceInputButton extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback? onChanged;
  final String label;

  const VoiceInputButton({
    super.key,
    required this.controller,
    this.onChanged,
    this.label = "음성 입력",
  });

  @override
  State<VoiceInputButton> createState() => _VoiceInputButtonState();
}

class _VoiceInputButtonState extends State<VoiceInputButton> {
  final SpeechToText _stt = SpeechToText();
  bool _listening = false;
  String _base = '';

  @override
  void dispose() {
    _stt.cancel();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _toggle() async {
    if (_listening) {
      await _stt.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    final ok = await _stt.initialize(
      onStatus: (s) {
        if ((s == 'done' || s == 'notListening') && mounted) {
          setState(() => _listening = false);
        }
      },
      onError: (e) {
        if (mounted) setState(() => _listening = false);
        _toast("음성 인식 오류: ${e.errorMsg}");
      },
    );
    if (!ok) {
      _toast("음성 인식을 사용할 수 없습니다. 마이크 권한과 구글 음성 서비스를 확인해 주십시오.");
      return;
    }
    _base = widget.controller.text.trimRight();
    setState(() => _listening = true);
    await _stt.listen(
      onResult: (r) {
        final words = r.recognizedWords;
        widget.controller.text = _base.isEmpty ? words : '$_base $words';
        widget.controller.selection = TextSelection.collapsed(
          offset: widget.controller.text.length,
        );
        widget.onChanged?.call();
      },
      // ignore: deprecated_member_use
      localeId: 'ko_KR',
      // ignore: deprecated_member_use
      listenFor: const Duration(seconds: 60),
      // ignore: deprecated_member_use
      pauseFor: const Duration(seconds: 5),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        listenMode: ListenMode.dictation,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: _toggle,
      icon: Icon(
        _listening ? Icons.stop_circle_rounded : Icons.mic_rounded,
        size: 18,
        color: _listening ? Colors.red : const Color(0xFF007580),
      ),
      label: Text(
        _listening ? "듣는 중… 눌러서 종료" : widget.label,
        style: TextStyle(
          color: _listening ? Colors.red : const Color(0xFF007580),
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 32),
      ),
    );
  }
}
