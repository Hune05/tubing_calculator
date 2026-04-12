import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
// ignore: deprecated_member_use
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// ---------------------------------------------------------
// 🎨 토스(Toss) 디자인 시스템 색상
// ---------------------------------------------------------
const Color tossBlue = Color(0xFF3182F6);
const Color tossText = Color(0xFF191F28);
const Color tossSubText = Color(0xFF8B95A1);
const Color tossBg = Color(0xFFF2F4F6);
const Color pureWhite = Color(0xFFFFFFFF);
const Color warningRed = Color(0xFFF04438);

// 🚀 치수선 색상 분리
const Color centerDimColor = Color(0xFF00C471); // 센터: 녹색
const Color edgeDimColor = Color(0xFFF68657); // 측면: 주황색
const Color guideCenterColor = tossBlue; // 가상선(센터): 파란색

// ---------------------------------------------------------
// 1. 데이터 모델
// ---------------------------------------------------------
enum DimensionType { center, edge }

abstract class MeasurePoint {
  Offset get center;
  Rect get boundingBox;
  String get id;
  Map<String, dynamic> toJson();
}

class PlacedItem implements MeasurePoint {
  @override
  final String id;
  String name;
  Offset position;
  double width;
  double height;
  bool isSelected;

  PlacedItem({
    required this.id,
    required this.name,
    required this.position,
    this.width = 80.0,
    this.height = 80.0,
    this.isSelected = false,
  });

  @override
  Offset get center =>
      Offset(position.dx + width / 2, position.dy + height / 2);

  @override
  Rect get boundingBox =>
      Rect.fromLTWH(position.dx, position.dy, width, height);

  @override
  Map<String, dynamic> toJson() => {
    'type': 'item',
    'id': id,
    'name': name,
    'x': position.dx,
    'y': position.dy,
    'w': width,
    'h': height,
  };
}

class WallPoint implements MeasurePoint {
  @override
  final String id;
  final Offset position;

  WallPoint({required this.position})
    : id = "wall_${position.dx}_${position.dy}";

  @override
  Offset get center => position;

  @override
  Rect get boundingBox => Rect.fromLTWH(position.dx, position.dy, 0, 0);

  @override
  Map<String, dynamic> toJson() => {
    'type': 'wall',
    'id': id,
    'x': position.dx,
    'y': position.dy,
  };
}

class PlacedDimension {
  final String id;
  final MeasurePoint p1;
  final MeasurePoint p2;
  final DimensionType type;

  PlacedDimension({
    required this.id,
    required this.p1,
    required this.p2,
    required this.type,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'p1': p1.toJson(),
    'p2': p2.toJson(),
    'type': type.name,
  };
}

// ---------------------------------------------------------
// 2. 메인 페이지 화면
// ---------------------------------------------------------
class MobileLayoutBoardPage extends StatefulWidget {
  final String? projectId;

  const MobileLayoutBoardPage({super.key, this.projectId});

  @override
  State<MobileLayoutBoardPage> createState() => _MobileLayoutBoardPageState();
}

class _MobileLayoutBoardPageState extends State<MobileLayoutBoardPage> {
  double _panelWidth = 600.0;
  double _panelHeight = 800.0;
  final double _gridSize = 5.0;

  bool _isDimensionMode = false;
  DimensionType _currentDimType = DimensionType.center;
  bool _isSaving = false;

  final List<PlacedItem> _placedItems = [];
  final List<PlacedDimension> _dimensions = [];

  MeasurePoint? _dimensionStartPoint;
  PlacedItem? _activeItem;
  PlacedItem? _previewItem;
  Offset _dragRawPosition = Offset.zero;

  final GlobalKey _boardKey = GlobalKey();
  final GlobalKey _captureKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.projectId != null) {
      // TODO: Firebase 로드 로직
    }
  }

  Offset _snapToGrid(Offset offset) {
    double dx = (offset.dx / _gridSize).round() * _gridSize;
    double dy = (offset.dy / _gridSize).round() * _gridSize;
    return Offset(dx, dy);
  }

  void _clearBoard() {
    setState(() {
      _placedItems.clear();
      _dimensions.clear();
      _dimensionStartPoint = null;
      _activeItem = null;
      _previewItem = null;
    });
  }

  Future<Uint8List?> _capturePng() async {
    try {
      RenderRepaintBoundary boundary =
          _captureKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      return byteData?.buffer.asUint8List();
    } catch (e) {
      return null;
    }
  }

  Future<void> _shareAsPdf(String projectName) async {
    setState(() => _isSaving = true);
    try {
      final imageBytes = await _capturePng();
      if (imageBytes == null) throw Exception("도면 캡처 실패");

      final pdf = pw.Document();
      final image = pw.MemoryImage(imageBytes);
      String qrData =
          "tubingcalc://layout?project=${projectName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}";

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          "Smart Panel Layout Report",
                          style: pw.TextStyle(
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Text(
                          "Project: $projectName",
                          style: const pw.TextStyle(fontSize: 14),
                        ),
                        pw.Text(
                          "Panel Size: ${_panelWidth.toInt()}mm x ${_panelHeight.toInt()}mm",
                          style: const pw.TextStyle(fontSize: 14),
                        ),
                        pw.Text(
                          "Date: ${DateTime.now().toString().split('.')[0]}",
                          style: const pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ],
                    ),
                    pw.Container(
                      width: 80,
                      height: 80,
                      child: pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: qrData,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Expanded(
                  child: pw.Center(
                    child: pw.Image(image, fit: pw.BoxFit.contain),
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  "* Scan the QR code to open this layout in the Tubing Calculator App.",
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            );
          },
        ),
      );

      final output = await getTemporaryDirectory();
      final file = File("${output.path}/${projectName}_Layout.pdf");
      await file.writeAsBytes(await pdf.save());

      if (!mounted) return;
      // ignore: deprecated_member_use
      await Share.shareXFiles([
        XFile(file.path),
      ], text: '$projectName 레이아웃 도면입니다.');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("PDF 생성 오류: $e")));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveToFirebase(String projectName) async {
    setState(() => _isSaving = true);
    try {
      final docRef = FirebaseFirestore.instance.collection('layouts').doc();
      await docRef.set({
        'projectId': docRef.id,
        'projectName': projectName,
        'panelWidth': _panelWidth,
        'panelHeight': _panelHeight,
        'createdAt': FieldValue.serverTimestamp(),
        'items': _placedItems.map((e) => e.toJson()).toList(),
        'dimensions': _dimensions.map((e) => e.toJson()).toList(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("프로젝트 저장 완료!"), backgroundColor: tossBlue),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("저장 실패"), backgroundColor: warningRed),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _onAcceptItem(String defaultName, Offset localPosition) {
    HapticFeedback.mediumImpact();
    setState(() {
      for (var item in _placedItems) item.isSelected = false;

      double clampedX = localPosition.dx.clamp(
        0.0,
        math.max(0.0, _panelWidth - 80.0),
      );
      double clampedY = localPosition.dy.clamp(
        0.0,
        math.max(0.0, _panelHeight - 80.0),
      );

      final newItem = PlacedItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: defaultName,
        position: _snapToGrid(Offset(clampedX, clampedY)),
        isSelected: true,
      );

      _placedItems.add(newItem);
      _activeItem = newItem;
      _previewItem = null;
    });
    _showInspectorBottomSheet(_placedItems.last);
  }

  WallPoint _getNearestWallPoint(Offset touchPosition) {
    double distLeft = touchPosition.dx;
    double distRight = _panelWidth - touchPosition.dx;
    double distTop = touchPosition.dy;
    double distBottom = _panelHeight - touchPosition.dy;

    double minDist = [
      distLeft,
      distRight,
      distTop,
      distBottom,
    ].reduce(math.min);
    Offset wallPos;
    if (minDist == distLeft)
      wallPos = Offset(0, touchPosition.dy);
    else if (minDist == distRight)
      wallPos = Offset(_panelWidth, touchPosition.dy);
    else if (minDist == distTop)
      wallPos = Offset(touchPosition.dx, 0);
    else
      wallPos = Offset(touchPosition.dx, _panelHeight);

    return WallPoint(position: _snapToGrid(wallPos));
  }

  void _handleDimensionPoint(MeasurePoint point) {
    setState(() {
      if (_dimensionStartPoint == null) {
        _dimensionStartPoint = point;
      } else {
        if (_dimensionStartPoint!.id != point.id) {
          bool exists = _dimensions.any(
            (dim) =>
                (dim.p1.id == _dimensionStartPoint!.id &&
                    dim.p2.id == point.id) ||
                (dim.p1.id == point.id &&
                    dim.p2.id == _dimensionStartPoint!.id),
          );

          if (!exists) {
            _dimensions.add(
              PlacedDimension(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                p1: _dimensionStartPoint!,
                p2: point,
                type: _currentDimType,
              ),
            );
            HapticFeedback.heavyImpact();
          }
        }
        _dimensionStartPoint = null;
      }
    });
  }

  void _onTapItem(PlacedItem item) {
    HapticFeedback.lightImpact();
    if (_isDimensionMode) {
      _handleDimensionPoint(item);
    } else {
      setState(() {
        for (var i in _placedItems) i.isSelected = false;
        item.isSelected = true;
        _activeItem = item;
      });
      _showInspectorBottomSheet(item);
    }
  }

  void _onTapBoard(Offset localPosition) {
    if (_isDimensionMode) {
      HapticFeedback.lightImpact();
      WallPoint nearestWall = _getNearestWallPoint(localPosition);
      _handleDimensionPoint(nearestWall);
    } else {
      setState(() {
        for (var i in _placedItems) i.isSelected = false;
        _activeItem = null;
      });
    }
  }

  Widget _buildBottomSheetHandle() {
    return Center(
      child: Container(
        width: 40,
        height: 5,
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _showSaveActionSheet() {
    final TextEditingController projectCtrl = TextEditingController(
      text: "현장 레이아웃_${DateTime.now().day}일",
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            top: 16,
            left: 24,
            right: 24,
          ),
          decoration: const BoxDecoration(
            color: pureWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBottomSheetHandle(),
              const Text(
                "저장 및 공유하기",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: tossText,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: projectCtrl,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: tossText,
                ),
                decoration: InputDecoration(
                  labelText: "프로젝트/현장 명칭",
                  filled: true,
                  fillColor: tossBg,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _saveToFirebase(projectCtrl.text);
                  },
                  icon: const Icon(
                    Icons.cloud_upload_rounded,
                    color: pureWhite,
                  ),
                  label: const Text(
                    "프로젝트 서버에 저장",
                    style: TextStyle(
                      color: pureWhite,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tossBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _shareAsPdf(projectCtrl.text);
                  },
                  icon: const Icon(
                    Icons.picture_as_pdf_rounded,
                    color: tossText,
                  ),
                  label: const Text(
                    "QR 도면 PDF로 공유",
                    style: TextStyle(
                      color: tossText,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: tossText, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showInspectorBottomSheet(PlacedItem item) {
    final TextEditingController nameCtrl = TextEditingController(
      text: item.name,
    );
    final TextEditingController widthCtrl = TextEditingController(
      text: item.width.toInt().toString(),
    );
    final TextEditingController heightCtrl = TextEditingController(
      text: item.height.toInt().toString(),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.15),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                top: 16,
                left: 24,
                right: 24,
              ),
              decoration: BoxDecoration(
                color: pureWhite,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 30,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBottomSheetHandle(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "모듈 속성 편집",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: tossText,
                          letterSpacing: -0.5,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: tossSubText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 🚀 [여기가 핵심 추가본입니다] 회전 & 복사 버튼
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // 🔄 90도 회전 (가로 세로 길이 교환)
                            setState(() {
                              double temp = item.width;
                              item.width = item.height;
                              item.height = temp;

                              // 회전 후 도면 밖으로 나가지 않게 위치 보정
                              item.position = Offset(
                                item.position.dx.clamp(
                                  0.0,
                                  math.max(0.0, _panelWidth - item.width),
                                ),
                                item.position.dy.clamp(
                                  0.0,
                                  math.max(0.0, _panelHeight - item.height),
                                ),
                              );
                            });
                            // 바텀시트의 텍스트 필드 값도 함께 업데이트
                            setModalState(() {
                              widthCtrl.text = item.width.toInt().toString();
                              heightCtrl.text = item.height.toInt().toString();
                            });
                            HapticFeedback.lightImpact();
                          },
                          icon: const Icon(
                            Icons.rotate_90_degrees_cw_rounded,
                            size: 18,
                            color: tossBlue,
                          ),
                          label: const Text(
                            "90° 회전",
                            style: TextStyle(
                              color: tossBlue,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: tossBlue.withValues(alpha: 0.1),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // 📋 모듈 복사
                            setState(() {
                              final newItem = PlacedItem(
                                id: DateTime.now().millisecondsSinceEpoch
                                    .toString(),
                                name: item.name,
                                position: _snapToGrid(
                                  Offset(
                                    (item.position.dx + 20).clamp(
                                      0.0,
                                      math.max(0.0, _panelWidth - item.width),
                                    ),
                                    (item.position.dy + 20).clamp(
                                      0.0,
                                      math.max(0.0, _panelHeight - item.height),
                                    ),
                                  ),
                                ),
                                width: item.width,
                                height: item.height,
                                isSelected: false,
                              );
                              _placedItems.add(newItem);
                            });
                            HapticFeedback.mediumImpact();
                            Navigator.pop(context); // 복제 후 창 닫기

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("'${item.name}' 모듈이 복사되었습니다."),
                                backgroundColor: tossText,
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.content_copy_rounded,
                            size: 18,
                            color: tossText,
                          ),
                          label: const Text(
                            "모듈 복제",
                            style: TextStyle(
                              color: tossText,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: tossBg,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: tossText,
                    ),
                    decoration: InputDecoration(
                      labelText: "모듈 명칭 (라벨)",
                      filled: true,
                      fillColor: tossBg,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) {
                      setState(() {
                        item.name = val.isEmpty ? "이름 없음" : val;
                      });
                    },
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    "모듈 크기 (가로 x 세로)",
                    style: TextStyle(
                      color: tossText,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildCoordinateInput(
                          "가로 너비 (mm)",
                          widthCtrl.text,
                          (val) {
                            setState(() {
                              item.width = (double.tryParse(val) ?? 80.0);
                              item.position = Offset(
                                item.position.dx.clamp(
                                  0.0,
                                  math.max(0.0, _panelWidth - item.width),
                                ),
                                item.position.dy,
                              );
                            });
                          },
                          controller: widthCtrl,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildCoordinateInput(
                          "세로 높이 (mm)",
                          heightCtrl.text,
                          (val) {
                            setState(() {
                              item.height = (double.tryParse(val) ?? 80.0);
                              item.position = Offset(
                                item.position.dx,
                                item.position.dy.clamp(
                                  0.0,
                                  math.max(0.0, _panelHeight - item.height),
                                ),
                              );
                            });
                          },
                          controller: heightCtrl,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    "도면 내 절대 위치",
                    style: TextStyle(
                      color: tossText,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildCoordinateInput(
                          "X 좌표 (mm)",
                          item.position.dx.toInt().toString(),
                          (val) {
                            setState(() {
                              double newX = double.tryParse(val) ?? 0;
                              item.position = Offset(
                                newX.clamp(
                                  0.0,
                                  math.max(0.0, _panelWidth - item.width),
                                ),
                                item.position.dy,
                              );
                            });
                            setModalState(() {});
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildCoordinateInput(
                          "Y 좌표 (mm)",
                          item.position.dy.toInt().toString(),
                          (val) {
                            setState(() {
                              double newY = double.tryParse(val) ?? 0;
                              item.position = Offset(
                                item.position.dx,
                                newY.clamp(
                                  0.0,
                                  math.max(0.0, _panelHeight - item.height),
                                ),
                              );
                            });
                            setModalState(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 36),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _dimensions.removeWhere(
                            (dim) =>
                                dim.p1.id == item.id || dim.p2.id == item.id,
                          );
                          _placedItems.remove(item);
                          if (_dimensionStartPoint?.id == item.id)
                            _dimensionStartPoint = null;
                          _activeItem = null;
                        });
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.delete_outline, color: warningRed),
                      label: const Text(
                        "이 모듈 삭제",
                        style: TextStyle(
                          color: warningRed,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: warningRed, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      setState(() {
        item.isSelected = false;
        _activeItem = null;
      });
    });
  }

  void _showPanelSettingsSheet() {
    final widthCtrl = TextEditingController(
      text: _panelWidth.toInt().toString(),
    );
    final heightCtrl = TextEditingController(
      text: _panelHeight.toInt().toString(),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            top: 16,
            left: 24,
            right: 24,
          ),
          decoration: const BoxDecoration(
            color: pureWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBottomSheetHandle(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "레이아웃 크기 설정",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: tossText,
                      letterSpacing: -0.5,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: tossSubText),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                "실제 중판(캐비닛)의 사이즈를 mm 단위로 입력하세요.",
                style: TextStyle(color: tossSubText, fontSize: 14),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: _buildCoordinateInput(
                      "가로 (W) mm",
                      widthCtrl.text,
                      (val) {},
                      controller: widthCtrl,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildCoordinateInput(
                      "세로 (H) mm",
                      heightCtrl.text,
                      (val) {},
                      controller: heightCtrl,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _panelWidth = double.tryParse(widthCtrl.text) ?? 600.0;
                      _panelHeight = double.tryParse(heightCtrl.text) ?? 800.0;

                      for (var item in _placedItems) {
                        item.position = Offset(
                          item.position.dx.clamp(
                            0.0,
                            math.max(0.0, _panelWidth - item.width),
                          ),
                          item.position.dy.clamp(
                            0.0,
                            math.max(0.0, _panelHeight - item.height),
                          ),
                        );
                      }
                      _dimensions.removeWhere(
                        (dim) => dim.p1 is WallPoint || dim.p2 is WallPoint,
                      );
                    });
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tossBlue,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    "도면 크기 적용",
                    style: TextStyle(
                      color: pureWhite,
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: tossBg,
      appBar: AppBar(
        backgroundColor: pureWhite,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "스마트 레이아웃 설계",
          style: TextStyle(
            color: tossText,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: tossText,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: tossBlue,
                  ),
                ),
              ),
            )
          else
            IconButton(
              tooltip: "저장 및 공유",
              onPressed: _showSaveActionSheet,
              icon: const Icon(Icons.ios_share_rounded, color: tossBlue),
            ),
          IconButton(
            tooltip: "외함 사이즈 설정",
            onPressed: _showPanelSettingsSheet,
            icon: const Icon(Icons.aspect_ratio_rounded, color: tossText),
          ),
          IconButton(
            tooltip: "도면 초기화",
            onPressed: _clearBoard,
            icon: const Icon(Icons.refresh_rounded, color: warningRed),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: InteractiveViewer(
              minScale: 0.1,
              maxScale: 4.0,
              boundaryMargin: const EdgeInsets.all(2000),
              constrained: false,
              child: DragTarget<String>(
                onMove: (details) {
                  final RenderBox box =
                      _boardKey.currentContext!.findRenderObject() as RenderBox;
                  Offset localPos = box.globalToLocal(details.offset);
                  double clampedX = localPos.dx.clamp(
                    0.0,
                    math.max(0.0, _panelWidth - 80.0),
                  );
                  double clampedY = localPos.dy.clamp(
                    0.0,
                    math.max(0.0, _panelHeight - 80.0),
                  );
                  setState(() {
                    _previewItem = PlacedItem(
                      id: 'preview',
                      name: details.data,
                      position: _snapToGrid(Offset(clampedX, clampedY)),
                      width: 80,
                      height: 80,
                    );
                  });
                },
                onLeave: (data) => setState(() => _previewItem = null),
                onAcceptWithDetails: (details) {
                  final RenderBox box =
                      _boardKey.currentContext!.findRenderObject() as RenderBox;
                  _onAcceptItem(
                    details.data,
                    box.globalToLocal(details.offset),
                  );
                },
                builder: (context, candidateData, rejectedData) {
                  return Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      GestureDetector(
                        onTapUp: (details) =>
                            _onTapBoard(details.localPosition),
                        child: RepaintBoundary(
                          key: _captureKey,
                          child: Container(
                            key: _boardKey,
                            width: _panelWidth,
                            height: _panelHeight,
                            decoration: BoxDecoration(
                              color: pureWhite,
                              border: Border.all(color: tossText, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 30,
                                  offset: const Offset(10, 10),
                                ),
                              ],
                            ),
                            clipBehavior: Clip.hardEdge,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                CustomPaint(
                                  size: Size.infinite,
                                  painter: GridPainter(gridSize: _gridSize),
                                ),
                                CustomPaint(
                                  size: Size.infinite,
                                  painter: DimensionPainter(
                                    dimensions: _dimensions,
                                    activePoint: _dimensionStartPoint,
                                    panelWidth: _panelWidth,
                                    panelHeight: _panelHeight,
                                  ),
                                ),

                                if (_previewItem != null &&
                                    !_isDimensionMode) ...[
                                  CustomPaint(
                                    size: Size.infinite,
                                    painter: SmartGuidePainter(
                                      item: _previewItem!,
                                      allItems: _placedItems,
                                      panelWidth: _panelWidth,
                                      panelHeight: _panelHeight,
                                      currentType: _currentDimType,
                                    ),
                                  ),
                                  Positioned(
                                    left: _previewItem!.position.dx,
                                    top: _previewItem!.position.dy,
                                    child: Opacity(
                                      opacity: 0.5,
                                      child: _buildBoardItem(_previewItem!),
                                    ),
                                  ),
                                ],

                                if (_activeItem != null && !_isDimensionMode)
                                  CustomPaint(
                                    size: Size.infinite,
                                    painter: SmartGuidePainter(
                                      item: _activeItem!,
                                      allItems: _placedItems,
                                      panelWidth: _panelWidth,
                                      panelHeight: _panelHeight,
                                      currentType: _currentDimType,
                                    ),
                                  ),

                                ..._placedItems.map((item) {
                                  return Positioned(
                                    left: item.position.dx,
                                    top: item.position.dy,
                                    child: GestureDetector(
                                      onPanStart: !_isDimensionMode
                                          ? (details) {
                                              setState(() {
                                                _dragRawPosition =
                                                    item.position;
                                                _activeItem = item;
                                                for (var i in _placedItems) {
                                                  i.isSelected = false;
                                                }
                                                item.isSelected = true;
                                              });
                                            }
                                          : null,
                                      onPanUpdate: !_isDimensionMode
                                          ? (details) {
                                              setState(() {
                                                _dragRawPosition +=
                                                    details.delta;
                                                double clampedX =
                                                    _dragRawPosition.dx.clamp(
                                                      0.0,
                                                      math.max(
                                                        0.0,
                                                        _panelWidth -
                                                            item.width,
                                                      ),
                                                    );
                                                double clampedY =
                                                    _dragRawPosition.dy.clamp(
                                                      0.0,
                                                      math.max(
                                                        0.0,
                                                        _panelHeight -
                                                            item.height,
                                                      ),
                                                    );
                                                item.position = _snapToGrid(
                                                  Offset(clampedX, clampedY),
                                                );
                                              });
                                            }
                                          : null,
                                      onPanEnd: !_isDimensionMode
                                          ? (details) {
                                              setState(() {
                                                _activeItem = null;
                                              });
                                            }
                                          : null,
                                      onTap: () => _onTapItem(item),
                                      child: _buildBoardItem(item),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: -30,
                        child: Text(
                          "W: ${_panelWidth.toInt()} mm",
                          style: TextStyle(
                            color: Colors.blueGrey.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Positioned(
                        left: -80,
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: Text(
                            "H: ${_panelHeight.toInt()} mm",
                            style: TextStyle(
                              color: Colors.blueGrey.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          // 하단 컨트롤 패널
          Container(
            decoration: BoxDecoration(
              color: pureWhite,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(
                                value: false,
                                label: Text(
                                  "모듈 배치/이동",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              ButtonSegment(
                                value: true,
                                label: Text(
                                  "고정 치수 측정",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                            selected: {_isDimensionMode},
                            style: ButtonStyle(
                              backgroundColor:
                                  WidgetStateProperty.resolveWith<Color>((
                                    Set<WidgetState> states,
                                  ) {
                                    if (states.contains(WidgetState.selected))
                                      return tossText;
                                    return pureWhite;
                                  }),
                              foregroundColor:
                                  WidgetStateProperty.resolveWith<Color>((
                                    Set<WidgetState> states,
                                  ) {
                                    if (states.contains(WidgetState.selected))
                                      return pureWhite;
                                    return tossText;
                                  }),
                            ),
                            onSelectionChanged: (Set<bool> newSelection) {
                              setState(() {
                                _isDimensionMode = newSelection.first;
                                _dimensionStartPoint = null;
                                _activeItem = null;
                                for (var i in _placedItems) {
                                  i.isSelected = false;
                                }
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _isDimensionMode
                        ? _buildDimensionToolBar()
                        : _buildModulePalette(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModulePalette() {
    return Padding(
      key: const ValueKey("palette"),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ChoiceChip(
                label: const Text("가상선: 센터(파란색)"),
                selected: _currentDimType == DimensionType.center,
                selectedColor: guideCenterColor.withValues(alpha: 0.2),
                labelStyle: TextStyle(
                  color: _currentDimType == DimensionType.center
                      ? guideCenterColor
                      : tossSubText,
                  fontWeight: FontWeight.bold,
                ),
                onSelected: (val) {
                  setState(() {
                    _currentDimType = DimensionType.center;
                  });
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text("가상선: 측면(주황색)"),
                selected: _currentDimType == DimensionType.edge,
                selectedColor: edgeDimColor.withValues(alpha: 0.2),
                labelStyle: TextStyle(
                  color: _currentDimType == DimensionType.edge
                      ? edgeDimColor
                      : tossSubText,
                  fontWeight: FontWeight.bold,
                ),
                onSelected: (val) {
                  setState(() {
                    _currentDimType = DimensionType.edge;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Draggable<String>(
                data: "신규 박스",
                feedback: Material(
                  color: Colors.transparent,
                  child: Opacity(
                    opacity: 0.8,
                    child: _buildPaletteItem("드래그 중.."),
                  ),
                ),
                childWhenDragging: Opacity(
                  opacity: 0.3,
                  child: _buildPaletteItem("배치 중"),
                ),
                child: _buildPaletteItem("신규 모듈"),
              ),
              const SizedBox(width: 20),
              const Expanded(
                child: Text(
                  "도면으로 박스를 드래그하세요.\n위에 설정된 가상선 모드가 드래그 시 적용됩니다.",
                  style: TextStyle(
                    color: tossSubText,
                    fontSize: 13,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaletteItem(String defaultName) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: pureWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tossBlue.withValues(alpha: 0.4), width: 2),
        boxShadow: [
          BoxShadow(
            color: tossBlue.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_box_rounded, color: tossBlue, size: 28),
            const SizedBox(height: 6),
            Text(
              defaultName,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: tossBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDimensionToolBar() {
    return Padding(
      key: const ValueKey("dimension"),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ChoiceChip(
                label: const Text("센터(중심) 기준"),
                selected: _currentDimType == DimensionType.center,
                selectedColor: centerDimColor.withValues(alpha: 0.2),
                labelStyle: TextStyle(
                  color: _currentDimType == DimensionType.center
                      ? centerDimColor
                      : tossSubText,
                  fontWeight: FontWeight.bold,
                ),
                onSelected: (val) {
                  setState(() {
                    _currentDimType = DimensionType.center;
                  });
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text("측면(여백) 기준"),
                selected: _currentDimType == DimensionType.edge,
                selectedColor: edgeDimColor.withValues(alpha: 0.2),
                labelStyle: TextStyle(
                  color: _currentDimType == DimensionType.edge
                      ? edgeDimColor
                      : tossSubText,
                  fontWeight: FontWeight.bold,
                ),
                onSelected: (val) {
                  setState(() {
                    _currentDimType = DimensionType.edge;
                  });
                },
              ),
              const Spacer(),
              if (_dimensions.isNotEmpty)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _dimensions.clear();
                    });
                  },
                  child: const Text(
                    "전체 삭제",
                    style: TextStyle(
                      color: warningRed,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _dimensionStartPoint == null
                ? "💡 측정할 두 지점(모듈 or 벽면)을 순서대로 터치하세요."
                : "💡 다음 측정 지점을 터치하면 치수선이 연결됩니다.",
            style: TextStyle(
              color: _dimensionStartPoint == null
                  ? tossSubText
                  : (_currentDimType == DimensionType.center
                        ? centerDimColor
                        : edgeDimColor),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _currentDimType == DimensionType.center
                ? "⚠️ 현재 '센터(중앙점)' 간의 거리를 측정 중입니다."
                : "⚠️ 현재 박스 '끝단(측면/여백)' 간의 거리를 측정 중입니다.",
            style: TextStyle(
              color: _currentDimType == DimensionType.center
                  ? centerDimColor
                  : edgeDimColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoardItem(PlacedItem item) {
    bool isMeasuringStart =
        _isDimensionMode && _dimensionStartPoint?.id == item.id;
    Color activeColor = _currentDimType == DimensionType.center
        ? centerDimColor
        : edgeDimColor;

    return Container(
      width: item.width,
      height: item.height,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isMeasuringStart
            ? activeColor.withValues(alpha: 0.1)
            : pureWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isMeasuringStart
              ? activeColor
              : (item.isSelected ? tossBlue : Colors.blueGrey.shade300),
          width: isMeasuringStart || item.isSelected ? 3 : 1.5,
        ),
        boxShadow: item.isSelected
            ? [
                BoxShadow(
                  color: tossBlue.withValues(alpha: 0.25),
                  blurRadius: 15,
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(2, 2),
                ),
              ],
      ),
      child: Center(
        child: Text(
          item.name,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: isMeasuringStart
                ? activeColor
                : (item.isSelected ? tossBlue : tossText),
            height: 1.2,
            letterSpacing: -0.3,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildCoordinateInput(
    String label,
    String value,
    Function(String) onChanged, {
    TextEditingController? controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: tossSubText,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller:
              controller ??
              (TextEditingController(text: value)
                ..selection = TextSelection.collapsed(offset: value.length)),
          keyboardType: TextInputType.number,
          onSubmitted: onChanged,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: tossText,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: tossBg,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------
// Helper Painters
// ---------------------------------------------------------

// 🚀 [핵심 해결] 측면 모드에서도 레이캐스트(Raycast) 물리 법칙 완벽 적용
class SmartGuidePainter extends CustomPainter {
  final PlacedItem item;
  final List<PlacedItem> allItems;
  final double panelWidth;
  final double panelHeight;
  final DimensionType currentType;

  SmartGuidePainter({
    required this.item,
    required this.allItems,
    required this.panelWidth,
    required this.panelHeight,
    required this.currentType,
  });

  void _drawGuideLine(
    Canvas canvas,
    Offset start,
    Offset end,
    double distance,
    Color color,
    String prefix,
  ) {
    if (distance <= 2) return;

    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(start, end, linePaint);

    if (distance >= 10) {
      final textSpan = TextSpan(
        text: "$prefix ${distance.toInt()} mm",
        style: const TextStyle(
          color: pureWhite,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      final centerOffset = Offset(
        (start.dx + end.dx) / 2,
        (start.dy + end.dy) / 2,
      );

      final bgRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: centerOffset,
          width: textPainter.width + 16,
          height: textPainter.height + 10,
        ),
        const Radius.circular(12),
      );
      canvas.drawRRect(bgRect, Paint()..color = color);
      textPainter.paint(
        canvas,
        Offset(
          centerOffset.dx - textPainter.width / 2,
          centerOffset.dy - textPainter.height / 2,
        ),
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    Color c = currentType == DimensionType.center
        ? guideCenterColor
        : edgeDimColor;
    String p = currentType == DimensionType.center ? "센터" : "측면";

    double cx = item.center.dx, cy = item.center.dy;
    double left = item.position.dx, right = item.position.dx + item.width;
    double top = item.position.dy, bottom = item.position.dy + item.height;

    double bL = 0, bR = panelWidth, bT = 0, bB = panelHeight;

    for (var other in allItems) {
      if (other.id == item.id) continue;

      double oLeft = other.position.dx,
          oRight = other.position.dx + other.width;
      double oTop = other.position.dy,
          oBottom = other.position.dy + other.height;

      bool hitVerticalRay = (cx >= oLeft) && (cx <= oRight);
      if (hitVerticalRay) {
        if (currentType == DimensionType.center) {
          if (other.center.dy <= cy && other.center.dy > bT)
            bT = other.center.dy;
          if (other.center.dy >= cy && other.center.dy < bB)
            bB = other.center.dy;
        } else {
          if (oBottom <= top && oBottom > bT) bT = oBottom;
          if (oTop >= bottom && oTop < bB) bB = oTop;
        }
      }

      bool hitHorizontalRay = (cy >= oTop) && (cy <= oBottom);
      if (hitHorizontalRay) {
        if (currentType == DimensionType.center) {
          if (other.center.dx <= cx && other.center.dx > bL)
            bL = other.center.dx;
          if (other.center.dx >= cx && other.center.dx < bR)
            bR = other.center.dx;
        } else {
          if (oRight <= left && oRight > bL) bL = oRight;
          if (oLeft >= right && oLeft < bR) bR = oLeft;
        }
      }
    }

    if (currentType == DimensionType.center) {
      _drawGuideLine(
        canvas,
        Offset(cx, cy),
        Offset(cx, bT),
        (cy - bT).abs(),
        c,
        p,
      );
      _drawGuideLine(
        canvas,
        Offset(cx, cy),
        Offset(cx, bB),
        (bB - cy).abs(),
        c,
        p,
      );
      _drawGuideLine(
        canvas,
        Offset(cx, cy),
        Offset(bL, cy),
        (cx - bL).abs(),
        c,
        p,
      );
      _drawGuideLine(
        canvas,
        Offset(cx, cy),
        Offset(bR, cy),
        (bR - cx).abs(),
        c,
        p,
      );
    } else {
      _drawGuideLine(
        canvas,
        Offset(cx, top),
        Offset(cx, bT),
        (top - bT).abs(),
        c,
        p,
      );
      _drawGuideLine(
        canvas,
        Offset(cx, bottom),
        Offset(cx, bB),
        (bB - bottom).abs(),
        c,
        p,
      );
      _drawGuideLine(
        canvas,
        Offset(left, cy),
        Offset(bL, cy),
        (left - bL).abs(),
        c,
        p,
      );
      _drawGuideLine(
        canvas,
        Offset(right, cy),
        Offset(bR, cy),
        (bR - right).abs(),
        c,
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class GridPainter extends CustomPainter {
  final double gridSize;
  GridPainter({required this.gridSize});

  @override
  void paint(Canvas canvas, Size size) {
    final lightPaint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 0.5;
    final boldPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1.2;

    for (double i = 0; i <= size.width; i += gridSize) {
      bool isMajor = (i % (gridSize * 5) == 0);
      canvas.drawLine(
        Offset(i, 0),
        Offset(i, size.height),
        isMajor ? boldPaint : lightPaint,
      );
    }
    for (double i = 0; i <= size.height; i += gridSize) {
      bool isMajor = (i % (gridSize * 5) == 0);
      canvas.drawLine(
        Offset(0, i),
        Offset(size.width, i),
        isMajor ? boldPaint : lightPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class DimensionPainter extends CustomPainter {
  final List<PlacedDimension> dimensions;
  final MeasurePoint? activePoint;
  final double panelWidth;
  final double panelHeight;

  DimensionPainter({
    required this.dimensions,
    this.activePoint,
    required this.panelWidth,
    required this.panelHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (var dim in dimensions) {
      Color dColor = dim.type == DimensionType.center
          ? centerDimColor
          : edgeDimColor;
      String labelPrefix = dim.type == DimensionType.center ? "센터" : "측면";

      final linePaint = Paint()
        ..color = dColor.withValues(alpha: 0.8)
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;
      final dotPaint = Paint()..color = dColor;

      Rect r1 = dim.p1.boundingBox;
      Rect r2 = dim.p2.boundingBox;

      double dxCenter = (r1.center.dx - r2.center.dx).abs();
      double dyCenter = (r1.center.dy - r2.center.dy).abs();

      Offset startPt, endPt;
      double distance = 0;

      if (dim.type == DimensionType.center) {
        startPt = r1.center;
        endPt = r2.center;
        if (dxCenter > dyCenter) {
          endPt = Offset(endPt.dx, startPt.dy);
        } else {
          endPt = Offset(startPt.dx, endPt.dy);
        }
        distance = (startPt - endPt).distance;
      } else {
        if (dxCenter > dyCenter) {
          bool isR1Left = r1.center.dx < r2.center.dx;
          double x1 = isR1Left ? r1.right : r1.left;
          double x2 = isR1Left ? r2.left : r2.right;
          double y = (r1.center.dy + r2.center.dy) / 2;
          startPt = Offset(x1, y);
          endPt = Offset(x2, y);
          distance = (x1 - x2).abs();
        } else {
          bool isR1Top = r1.center.dy < r2.center.dy;
          double y1 = isR1Top ? r1.bottom : r1.top;
          double y2 = isR1Top ? r2.top : r2.bottom;
          double x = (r1.center.dx + r2.center.dx) / 2;
          startPt = Offset(x, y1);
          endPt = Offset(x, y2);
          distance = (y1 - y2).abs();
        }
      }

      canvas.drawLine(startPt, endPt, linePaint);
      canvas.drawCircle(startPt, 4, dotPaint);
      canvas.drawCircle(endPt, 4, dotPaint);

      if (distance >= 5) {
        final textSpan = TextSpan(
          text: "$labelPrefix ${distance.toInt()} mm",
          style: const TextStyle(
            color: pureWhite,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        );
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        )..layout();
        final centerOffset = Offset(
          (startPt.dx + endPt.dx) / 2,
          (startPt.dy + endPt.dy) / 2,
        );

        final bgRect = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: centerOffset,
            width: textPainter.width + 16,
            height: textPainter.height + 10,
          ),
          const Radius.circular(12),
        );
        canvas.drawRRect(bgRect, Paint()..color = dColor);
        textPainter.paint(
          canvas,
          Offset(
            centerOffset.dx - textPainter.width / 2,
            centerOffset.dy - textPainter.height / 2,
          ),
        );
      }
    }

    if (activePoint != null && activePoint is WallPoint) {
      canvas.drawCircle(activePoint!.center, 6, Paint()..color = tossText);
      canvas.drawCircle(
        activePoint!.center,
        16,
        Paint()
          ..color = tossText.withValues(alpha: 0.2)
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
