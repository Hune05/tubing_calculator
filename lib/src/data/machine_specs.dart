import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 벤더 제원 한 벌. 반경·게인·테이크업·피팅 깊이·벤더 오프셋·스프링백·
/// 톱날 손실과, 꼬리 길이·시작/끝 피팅 여부를 여기 하나에 둔다.
///
/// 🚀 [고침] 예전에는 폰 화면(MobileBendDataManager)과 태블릿·PC 화면
/// (BendDataManager)이 같은 저장 칸을 쓰면서도 각자 한 벌씩 들고 있었다.
/// 그래서 폰 설정에서 반경을 고쳐도 태블릿 마킹 화면은 앱을 껐다 켜기 전까지
/// 옛 반경으로 마킹을 찍었다. 현장에서 틀린 자리에 금을 긋게 되는 값이라
/// 한 벌만 두고 양쪽이 이것을 본다.
class MachineSpecs extends ChangeNotifier {
  static final MachineSpecs _instance = MachineSpecs._internal();
  factory MachineSpecs() => _instance;
  MachineSpecs._internal();

  String _pipeSize = '1/2"';
  bool _startFit = false;
  bool _endFit = false;
  double _tail = 0.0;
  double _fittingDepth = 0.0;
  double _takeUp90 = 0.0;
  double _gain90 = 0.0;
  double _radius = 0.0;
  double _benderOffset = 0.0;
  double _springback = 0.0;
  double _cutMargin = 0.0;

  String get pipeSize => _pipeSize;
  bool get startFit => _startFit;
  bool get endFit => _endFit;
  double get tail => _tail;
  double get fittingDepth => _fittingDepth;
  double get takeUp90 => _takeUp90;
  double get gain90 => _gain90;
  double get radius => _radius;
  double get benderOffset => _benderOffset;
  double get springback => _springback;
  double get cutMargin => _cutMargin;

  set pipeSize(String v) => _set(() => _pipeSize = v);
  set startFit(bool v) => _set(() => _startFit = v);
  set endFit(bool v) => _set(() => _endFit = v);
  set tail(double v) => _set(() => _tail = v);
  set fittingDepth(double v) => _set(() => _fittingDepth = v);
  set takeUp90(double v) => _set(() => _takeUp90 = v);
  set gain90(double v) => _set(() => _gain90 = v);
  set radius(double v) => _set(() => _radius = v);
  set benderOffset(double v) => _set(() => _benderOffset = v);
  set springback(double v) => _set(() => _springback = v);
  set cutMargin(double v) => _set(() => _cutMargin = v);

  void _set(VoidCallback change) {
    change();
    save();
    notifyListeners();
  }

  /// 여러 값을 한 번에 바꾼다(한 번만 저장하고 한 번만 알린다).
  void update({
    String? pipeSize,
    bool? startFit,
    bool? endFit,
    double? tail,
    double? fittingDepth,
    double? takeUp90,
    double? gain90,
    double? radius,
    double? benderOffset,
    double? springback,
    double? cutMargin,
  }) {
    if (pipeSize != null) _pipeSize = pipeSize;
    if (startFit != null) _startFit = startFit;
    if (endFit != null) _endFit = endFit;
    if (tail != null) _tail = tail;
    if (fittingDepth != null) _fittingDepth = fittingDepth;
    if (takeUp90 != null) _takeUp90 = takeUp90;
    if (gain90 != null) _gain90 = gain90;
    if (radius != null) _radius = radius;
    if (benderOffset != null) _benderOffset = benderOffset;
    if (springback != null) _springback = springback;
    if (cutMargin != null) _cutMargin = cutMargin;
    save();
    notifyListeners();
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    final isInch = prefs.getBool('isInch') ?? false;
    final tubeOD = prefs.getDouble('tubeOD') ?? (isInch ? 0.5 : 12.7);
    _pipeSize = isInch ? '$tubeOD"' : '${tubeOD}mm';

    _startFit = prefs.getBool('start_fit') ?? false;
    _endFit = prefs.getBool('end_fit') ?? false;
    _tail = prefs.getDouble('tail_length') ?? 0.0;
    _fittingDepth = prefs.getDouble('fittingDepth') ?? 0.0;
    _takeUp90 = prefs.getDouble('takeUp') ?? 0.0;
    _gain90 = prefs.getDouble('gain') ?? 0.0;
    _radius = prefs.getDouble('bendRadius') ?? 0.0;
    _benderOffset = prefs.getDouble('benderOffset') ?? 0.0;
    _springback = prefs.getDouble('springback') ?? 0.0;
    _cutMargin = prefs.getDouble('cutMargin') ?? 0.0;

    notifyListeners();
  }

  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('start_fit', _startFit);
      await prefs.setBool('end_fit', _endFit);
      await prefs.setDouble('tail_length', _tail);
      await prefs.setDouble('fittingDepth', _fittingDepth);
      await prefs.setDouble('takeUp', _takeUp90);
      await prefs.setDouble('gain', _gain90);
      await prefs.setDouble('bendRadius', _radius);
      await prefs.setDouble('benderOffset', _benderOffset);
      await prefs.setDouble('springback', _springback);
      await prefs.setDouble('cutMargin', _cutMargin);
    } catch (_) {}
  }

  /// 검사용. 값을 처음 상태로 되돌린다.
  @visibleForTesting
  void resetForTest() {
    _pipeSize = '1/2"';
    _startFit = false;
    _endFit = false;
    _tail = 0.0;
    _fittingDepth = 0.0;
    _takeUp90 = 0.0;
    _gain90 = 0.0;
    _radius = 0.0;
    _benderOffset = 0.0;
    _springback = 0.0;
    _cutMargin = 0.0;
  }
}
