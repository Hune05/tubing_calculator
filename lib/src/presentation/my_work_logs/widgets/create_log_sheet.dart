import 'package:flutter/material.dart';
import '../models/project_phase.dart' show kProjectTypes;

const Color tossBlue = Color(0xFF007580); // 🚀 마키타 틸로 통일
const Color tossText = Color(0xFF191F28);
const Color tossSubText = Color(0xFF8B95A1);
const Color tossInputBg = Color(0xFFF2F4F6); // 토스 특유의 옅은 회색 입력창
const Color pureWhite = Color(0xFFFFFFFF);

class CreateLogSheet extends StatefulWidget {
  const CreateLogSheet({super.key});

  static Future<Map<String, dynamic>?> show(BuildContext context) {
    return showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CreateLogSheet(),
    );
  }

  @override
  State<CreateLogSheet> createState() => _CreateLogSheetState();
}

class _CreateLogSheetState extends State<CreateLogSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _revController = TextEditingController();
  String? _workType;
  int? _remindMinutes; // null이면 기본 시간을 쓴다

  Future<void> _pickRemindTime() async {
    // 시간 창을 닫은 뒤 이름 입력칸으로 포커스가 돌아와 키보드가 다시 뜨지 않게 미리 내려 둔다.
    FocusManager.instance.primaryFocus?.unfocus();
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: (_remindMinutes ?? 18 * 60) ~/ 60,
        minute: (_remindMinutes ?? 18 * 60) % 60,
      ),
    );
    if (t != null) setState(() => _remindMinutes = t.hour * 60 + t.minute);
  }

  String _hm(int m) =>
      "${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}";

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final today = DateTime.now();
    final newLog = {
      "id": today.millisecondsSinceEpoch.toString(),
      "name": name,
      "date":
          "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')} ~ 진행중",
      "revision": _revController.text.trim().isEmpty
          ? "기준 도면 없음"
          : _revController.text.trim(),
      if (_workType != null) "workType": _workType,
      if (_remindMinutes != null) "reportReminderMinutes": _remindMinutes,
      "status": "ONGOING",
      "progress": 0.0,
      "isDeducted": false,
      "materials": [],
      "daily_reports": [],
      "punch_lists": [],
    };

    Navigator.of(context).pop(newLog);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _revController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: const BoxDecoration(
          color: pureWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 토스 스타일 상단 손잡이(Pill)
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D6DB),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                "새로운 작업을\n시작하시겠습니까?",
                style: TextStyle(
                  color: tossText,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 32),

              // 토스 스타일 입력창 (테두리 없이 둥근 회색 배경)
              TextField(
                controller: _nameController,
                autofocus: true,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: tossText,
                ),
                decoration: InputDecoration(
                  labelText: "작업 명칭 (현장명)",
                  labelStyle: const TextStyle(color: tossSubText, fontSize: 15),
                  filled: true,
                  fillColor: tossInputBg,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _revController,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: tossText,
                ),
                decoration: InputDecoration(
                  labelText: "기준 도면 / 리비전",
                  labelStyle: const TextStyle(color: tossSubText, fontSize: 15),
                  hintText: "예: Rev.0",
                  hintStyle: const TextStyle(color: Color(0xFFB0B8C1)),
                  filled: true,
                  fillColor: tossInputBg,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "공사 유형 (선택)",
                style: TextStyle(color: tossSubText, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in kProjectTypes)
                    ChoiceChip(
                      label: Text(t),
                      selected: _workType == t,
                      showCheckmark: false,
                      onSelected: (v) =>
                          setState(() => _workType = v ? t : null),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                "작업 일지 알림 시간 (선택)",
                style: TextStyle(color: tossSubText, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.alarm_rounded, size: 16),
                    label: Text(
                      _remindMinutes == null
                          ? "기본 시간 사용"
                          : _hm(_remindMinutes!),
                    ),
                    onPressed: _pickRemindTime,
                  ),
                  if (_remindMinutes != null)
                    TextButton(
                      onPressed: () => setState(() => _remindMinutes = null),
                      child: const Text("기본으로"),
                    ),
                ],
              ),
              const SizedBox(height: 32),

              // 토스 스타일 꽉 차는 메인 버튼
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tossBlue,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _submit,
                  child: const Text(
                    "만들기",
                    style: TextStyle(
                      color: pureWhite,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
