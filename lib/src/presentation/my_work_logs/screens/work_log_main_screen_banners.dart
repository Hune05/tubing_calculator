// ignore_for_file: invalid_use_of_protected_member
part of 'work_log_main_screen.dart';

// 🚀 banners 부분(화면 클래스에서 옮겨 온 메서드들, 동작은 그대로).
extension _WorkLogMainBanners on _WorkLogMainScreenState {
  Widget _buildBackupBanner() {
    if (!_backupFailed) return const SizedBox.shrink();
    const c = Color(0xFFC77700);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 16, color: c),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              keepWords("주간 자동 백업에 실패했습니다. 앱이 켜져 있는 동안 계속 다시 시도합니다."),
              style: TextStyle(
                color: c,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
          TextButton(
            onPressed: _runAutoBackup,
            style: TextButton.styleFrom(
              foregroundColor: c,
              minimumSize: const Size(0, 32),
            ),
            child: const Text(
              "지금 시도",
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncBanner() {
    return ValueListenableBuilder<int>(
      valueListenable: WorkProjectRepository.pendingWrites,
      builder: (context, pending, _) {
        final uploading = _uploading.isNotEmpty;
        if (pending == 0 && _localPhotos == 0 && !uploading) {
          return const SizedBox.shrink();
        }
        String text;
        bool warn = false;
        if (uploading) {
          text = "사진 올리는 중… (남은 사진 $_localPhotos장)";
        } else if (_localPhotos > 0) {
          text = "사진 $_localPhotos장이 아직 올라가지 않았습니다. 네트워크를 확인해 주십시오.";
          warn = true;
        } else {
          text = "변경사항을 서버에 저장하는 중입니다. 오프라인이면 연결될 때 자동으로 올라갑니다.";
        }
        final color = warn ? const Color(0xFFC77700) : tossBlue;
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              if (uploading || (pending > 0 && _localPhotos == 0))
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              else
                Icon(Icons.cloud_off_rounded, size: 16, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ),
              if (!uploading && _localPhotos > 0)
                TextButton(
                  onPressed: _retryUploads,
                  style: TextButton.styleFrom(
                    foregroundColor: color,
                    minimumSize: const Size(0, 32),
                  ),
                  child: const Text(
                    "다시 시도",
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
