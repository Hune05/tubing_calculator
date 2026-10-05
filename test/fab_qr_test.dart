import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:tubing_calculator/src/presentation/fabrication/fab_qr.dart';

List<Map<String, dynamic>> _bends() => [
      {'length': 120.0, 'angle': 0, 'rotation': 0, 'mark': 0},
      {'length': 85.5, 'angle': 90, 'rotation': -90, 'mark': 140.25},
      {'length': 60.0, 'angle': 45.5, 'rotation': 180, 'mark': 220},
    ];

FabQrLink _link({List<Map<String, dynamic>>? bends, String project = '1호기 배관'}) =>
    FabQr.build(
      project: project,
      pipeSize: '1/2"',
      bends: bends ?? _bends(),
      startFit: true,
      endFit: false,
      tail: 25,
      startDir: 'LEFT',
      totalCut: 530.5,
      now: DateTime(2026, 10, 5, 15, 20),
    );

void main() {
  test('만든 QR을 그대로 읽으면 값이 같고 음수 회전도 유지된다', () {
    final r = FabQr.parse(_link().url);
    expect(r.error, isNull);
    final d = r.data!;
    expect(d.legacy, isFalse);
    expect(d.project, '1호기 배관');
    expect(d.pipeSize, '1/2"');
    expect(d.bends.length, 3);
    expect(d.bends[1]['rotation'], -90.0);
    expect(d.bends[1]['mark'], 140.25);
    expect(d.bends[2]['angle'], 45.5);
    expect(d.bends[0]['is_straight'], isTrue);
    expect(d.startFit, isTrue);
    expect(d.endFit, isFalse);
    expect(d.tail, 25.0);
    expect(d.startDir, 'LEFT');
    expect(d.totalCut, 530.5);
    expect(d.savedAt, DateTime(2026, 10, 5, 15, 20));
    expect(d.code, _link().code);
  });

  test('값이 하나라도 바뀌면 열지 않는다', () {
    final url = _link().url;
    final tampered = url.replaceFirst('85.50', '95.50').replaceFirst('85.5', '95.5');
    expect(tampered, isNot(url));
    final r = FabQr.parse(tampered);
    expect(r.data, isNull);
    expect(r.error, contains('손상'));
  });

  test('검사 번호나 총 길이가 빠진 새 형식은 열지 않는다', () {
    final url = _link().url;
    final noCheck = url.replaceFirst(RegExp(r'&c=[0-9A-F]+'), '');
    expect(FabQr.parse(noCheck).data, isNull);
  });

  test('다른 QR이나 값이 빠진 QR은 기본값으로 열지 않고 이유를 알려 준다', () {
    expect(FabQr.parse('https://example.com').error, contains('도면 QR이 아닙니다'));
    expect(FabQr.parse('tubingcalc://layout?project=abc').data, isNull);
    expect(FabQr.parse('tubingapp://view?p=A&b=10_90_0').data, isNull); // 규격 없음
    expect(FabQr.parse('tubingapp://view?p=A&s=1%2F2&b=').data, isNull); // 벤딩 없음
  });

  test('옛 형식(v 없음, - 구분)은 옛 형식 표시로 열린다', () {
    final r = FabQr.parse(
      'tubingapp://view?p=A&s=1%2F2%22&b=120_0_0_0-85_90_90_140&sf=true&ef=false&t=25&d=LEFT',
    );
    expect(r.error, isNull);
    expect(r.data!.legacy, isTrue);
    expect(r.data!.bends.length, 2);
    expect(r.data!.bends[1]['angle'], 90.0);
    expect(r.data!.code, isNull);
    expect(r.data!.totalCut, isNull);
  });

  test('옛 형식에 숫자가 아닌 값이 있으면 거절한다', () {
    final r = FabQr.parse('tubingapp://view?p=A&s=1%2F2&b=12x_0_0-85_90_90');
    expect(r.data, isNull);
    expect(r.error, contains('벤딩 값'));
  });

  test('각도 범위를 벗어나면 거절한다', () {
    final bad = FabQr.build(
      project: 'A',
      pipeSize: '1/2"',
      bends: [
        {'length': 10.0, 'angle': 400, 'rotation': 0, 'mark': 0},
      ],
      startFit: false,
      endFit: false,
      tail: 0,
      startDir: 'RIGHT',
      totalCut: 10,
    );
    expect(FabQr.parse(bad.url).error, contains('범위'));
  });

  test('벤딩이 많으면 촘촘하다고 알린다', () {
    final many = List.generate(
      30,
      (i) => {'length': 123.45 + i, 'angle': 90, 'rotation': 180, 'mark': 456.78 + i},
    );
    expect(_link().dense, isFalse);
    expect(_link(bends: many).dense, isTrue);
  });

  test('종이에 적는 글: 저장 일시와 확인 번호(4자리)', () {
    final l = _link();
    expect(l.savedText, '2026-10-05 15:20');
    expect(l.code.length, 4);
  });

  test('PDF에 넣어도 만들어지고, 용량을 넘으면 QR 대신 안내가 들어간다', () async {
    Future<int> make(FabQrLink l) async {
      final pdf = pw.Document();
      pdf.addPage(pw.Page(build: (_) => FabQr.pdfWidget(l)));
      return (await pdf.save()).length;
    }

    final many = List.generate(
      30,
      (i) => {'length': 123.45 + i, 'angle': 90, 'rotation': 180, 'mark': 456.78 + i},
    );
    final huge = List.generate(
      120,
      (i) => {'length': 123.45 + i, 'angle': 90, 'rotation': 180, 'mark': 456.78 + i},
    );
    expect(await make(_link()), greaterThan(0));
    expect(await make(_link(bends: many)), greaterThan(0));
    final h = _link(bends: huge);
    expect(h.tooLong, isTrue);
    expect(await make(h), greaterThan(0));
  });
}
