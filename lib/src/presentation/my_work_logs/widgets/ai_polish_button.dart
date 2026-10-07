import 'package:flutter/material.dart';
import 'package:tubing_calculator/src/core/theme/app_tokens.dart';
import 'package:tubing_calculator/src/core/utils/ai_polish.dart';

/// 글칸 아래에 붙이는 "AI로 다듬기" 단추. 누르면 원문과 다듬은 글을 나란히 보여 주고,
/// 사용자가 "바꾸기"를 눌러야만 글칸이 바뀐다. 실패하면 글은 그대로다.
class AiPolishButton extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback? onChanged;
  final AiPolishCall polish;

  const AiPolishButton({
    super.key,
    required this.controller,
    this.onChanged,
    this.polish = callAiPolish,
  });

  @override
  State<AiPolishButton> createState() => _AiPolishButtonState();
}

class _AiPolishButtonState extends State<AiPolishButton> {
  bool _busy = false;

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _run() async {
    final original = widget.controller.text.trim();
    if (original.length < 2) {
      _toast('다듬을 글을 먼저 적어 주십시오');
      return;
    }
    setState(() => _busy = true);
    final res = await widget.polish(original);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!res.ok) {
      _toast(res.error ?? 'AI 다듬기에 실패했습니다');
      return;
    }
    final accepted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CompareSheet(original: original, polished: res.text!, remaining: res.remaining),
    );
    if (accepted == true && mounted) {
      // 기다리는 사이 글을 더 썼으면 통째로 바꾸지 않는다(10-08: 더 쓴 글이 사라졌다).
      if (widget.controller.text.trim() != original) {
        _toast('다듬는 사이 글이 바뀌어 바꾸지 않았습니다. 다시 다듬어 주십시오.');
        return;
      }
      widget.controller.text = res.text!;
      widget.controller.selection = TextSelection.collapsed(offset: res.text!.length);
      widget.onChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: _busy ? null : _run,
      icon: _busy
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.auto_fix_high_rounded, size: 18, color: AppColors.brand),
      label: Text(
        _busy ? '다듬는 중…' : 'AI로 다듬기',
        style: const TextStyle(color: AppColors.brand, fontWeight: FontWeight.w700, fontSize: 12),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 32),
      ),
    );
  }
}

class _CompareSheet extends StatelessWidget {
  final String original;
  final String polished;
  final int? remaining;
  const _CompareSheet({required this.original, required this.polished, this.remaining});

  @override
  Widget build(BuildContext context) {
    final sub = Theme.of(context).textTheme.bodySmall;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('내가 적은 글', style: sub),
              const SizedBox(height: 4),
              Text(original, style: const TextStyle(fontSize: 14, height: 1.5)),
              const SizedBox(height: 16),
              Text('다듬은 글', style: sub?.copyWith(color: AppColors.brand, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(polished, style: const TextStyle(fontSize: 15, height: 1.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(
                '숫자·규격이 맞는지 꼭 확인하십시오.${remaining == null ? '' : ' 오늘 $remaining번 더 쓸 수 있습니다.'}',
                style: sub,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('그대로 두기'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('바꾸기'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
