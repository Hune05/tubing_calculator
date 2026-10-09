import 'package:tubing_calculator/src/presentation/common/quick_tool_bar.dart';
import 'package:flutter/material.dart';
import '../models/plan_pin.dart';

// 🚀 [신규] 카카오톡 등으로 받은 실제 도면/배치도 사진 위에 이슈 발생
// 위치를 탭 한 번으로 찍는 화면. 좌표는 도면 그림 기준 0~1 비율(dx, dy)로
// 돌려준다(10-10: 예전에는 화면 몸통 기준이라 미리보기·PDF와 어긋났다 —
// plan_pin.dart). 부른 쪽은 [kPinOnImageKey]: true를 같이 저장한다.
class FloorPlanPinPage extends StatefulWidget {
  final String imagePath;
  final double? initialDx;
  final double? initialDy;
  // 처음 핀이 도면 그림 기준인지(예전 핀은 false — 이 화면 크기로 바꿔 보인다).
  final bool initialOnImage;

  const FloorPlanPinPage({
    super.key,
    required this.imagePath,
    this.initialDx,
    this.initialDy,
    this.initialOnImage = false,
  });

  @override
  State<FloorPlanPinPage> createState() => _FloorPlanPinPageState();
}

class _FloorPlanPinPageState extends State<FloorPlanPinPage> {
  Offset? _fraction; // 도면 그림 기준 0~1
  Size? _image;
  bool _initDone = false;

  @override
  void initState() {
    super.initState();
    planImageSize(widget.imagePath).then((s) {
      if (mounted) setState(() => _image = s);
    });
  }

  // 처음 핀: 그림 기준이면 그대로, 예전 핀이면 이 화면 몸통 크기로 바꾼다.
  void _initFraction(Size box) {
    if (_initDone || _image == null) return;
    _initDone = true;
    final dx = widget.initialDx, dy = widget.initialDy;
    if (dx == null || dy == null) return;
    _fraction = widget.initialOnImage
        ? Offset(dx, dy)
        : legacyPinToImage(Offset(dx, dy), _image!, box);
  }

  @override
  Widget build(BuildContext context) {
    return QuickBarSuppress(
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: const Text("도면을 탭해서 위치를 찍으십시오"),
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
            final box = Size(constraints.maxWidth, constraints.maxHeight);
            _initFraction(box);
            final image = _image;
            return SizedBox(
              width: box.width,
              height: box.height,
              child: GestureDetector(
                key: const Key('floor_plan_pin_area'),
                // 도면 크기를 읽기 전에는 찍지 않는다(어느 자리인지 알 수 없다).
                onTapUp: image == null
                    ? null
                    : (details) {
                        final RenderBox rb =
                            context.findRenderObject() as RenderBox;
                        final local = rb.globalToLocal(details.globalPosition);
                        setState(
                          () => _fraction = boxPointToImage(local, image, box),
                        );
                      },
                child: PlanPinsView(
                  imagePath: widget.imagePath,
                  imageSize: image,
                  pins: [
                    if (_fraction != null)
                      PlanPin(
                        _fraction!,
                        const Icon(
                          Icons.location_on,
                          color: Colors.redAccent,
                          size: 40,
                        ),
                        markerSize: const Size(40, 40),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
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
  // 핀이 도면 그림 기준인지([kPinOnImageKey]). 예전 핀은 false.
  final bool onImage;
  final double height;
  final VoidCallback? onTap;

  const FloorPlanThumbnail({
    super.key,
    required this.imagePath,
    this.dx,
    this.dy,
    this.onImage = false,
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
          child: FutureBuilder<Size?>(
            future: planImageSize(imagePath),
            builder: (_, snap) {
              final image = snap.data;
              final pin = (dx == null || dy == null)
                  ? null
                  : pinOnImageOf({
                      'locationPinDx': dx,
                      'locationPinDy': dy,
                      kPinOnImageKey: onImage,
                    }, image);
              return PlanPinsView(
                imagePath: imagePath,
                imageSize: image,
                pins: [
                  if (pin != null)
                    PlanPin(
                      pin,
                      const Icon(
                        Icons.location_on,
                        color: Colors.redAccent,
                        size: 28,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
