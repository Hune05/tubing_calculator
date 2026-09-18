import 'dart:io';
import 'package:flutter/material.dart';

// 🚀 [신규] 카카오톡 등으로 받은 실제 도면/배치도 사진 위에 이슈 발생
// 위치를 탭 한 번으로 찍는 화면. 좌표는 이미지 표시 영역 기준 0~1
// 비율(dx, dy)로 저장해서, 나중에 다른 크기로 그려도(썸네일/상세화면)
// 같은 상대 위치에 정확히 표시된다.
class FloorPlanPinPage extends StatefulWidget {
  final String imagePath;
  final double? initialDx;
  final double? initialDy;

  const FloorPlanPinPage({
    super.key,
    required this.imagePath,
    this.initialDx,
    this.initialDy,
  });

  @override
  State<FloorPlanPinPage> createState() => _FloorPlanPinPageState();
}

class _FloorPlanPinPageState extends State<FloorPlanPinPage> {
  Offset? _fraction; // 0~1 비율 좌표

  @override
  void initState() {
    super.initState();
    if (widget.initialDx != null && widget.initialDy != null) {
      _fraction = Offset(widget.initialDx!, widget.initialDy!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text("도면을 탭해서 위치를 찍으세요"),
        actions: [
          TextButton(
            onPressed: _fraction == null
                ? null
                : () => Navigator.pop(context, _fraction),
            child: const Text(
              "확인",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: GestureDetector(
              onTapUp: (details) {
                final RenderBox box = context.findRenderObject() as RenderBox;
                final local = box.globalToLocal(details.globalPosition);
                final double dx = (local.dx / box.size.width).clamp(0.0, 1.0);
                final double dy = (local.dy / box.size.height).clamp(0.0, 1.0);
                setState(() => _fraction = Offset(dx, dy));
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(File(widget.imagePath), fit: BoxFit.contain),
                  if (_fraction != null)
                    Align(
                      alignment: Alignment(
                        _fraction!.dx * 2 - 1,
                        _fraction!.dy * 2 - 1,
                      ),
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.redAccent,
                        size: 40,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// 🚀 [신규] 도면 이미지 + 핀 위치를 작게 미리보기로 보여주는 공용 위젯
// (이슈 등록 폼과 이슈 상세 화면 둘 다에서 재사용).
class FloorPlanThumbnail extends StatelessWidget {
  final String imagePath;
  final double? dx;
  final double? dy;
  final double height;
  final VoidCallback? onTap;

  const FloorPlanThumbnail({
    super.key,
    required this.imagePath,
    this.dx,
    this.dy,
    this.height = 150,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: double.infinity,
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(File(imagePath), fit: BoxFit.contain),
              if (dx != null && dy != null)
                Align(
                  alignment: Alignment(dx! * 2 - 1, dy! * 2 - 1),
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.redAccent,
                    size: 28,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
