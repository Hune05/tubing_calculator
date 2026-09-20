import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

// PDF에 쓰는 한글 글꼴(Noto Sans KR 보통·굵게).
// 예전에는 굵기 조절용 파일 하나(NotoSansKR-VariableFont_wght.ttf)를 PDF에 그대로 넣었는데,
// PDF 도구는 그 파일의 "가장 얇은 굵기"만 읽어서 글씨가 매우 가늘게 나왔다. 굵기별로 따로 만든
// 파일을 쓰면 보통 글씨와 굵은 글씨가 제대로 나온다. (글꼴 라이선스: OFL, assets/fonts/OFL-NotoSansKR.txt)
const String kPdfFontRegularAsset = 'assets/fonts/NotoSansKR-Regular.ttf';
const String kPdfFontBoldAsset = 'assets/fonts/NotoSansKR-Bold.ttf';

class KoreanPdfFonts {
  final pw.Font regular;
  final pw.Font bold;
  const KoreanPdfFonts(this.regular, this.bold);

  pw.ThemeData get theme => pw.ThemeData.withFont(base: regular, bold: bold);
}

Future<KoreanPdfFonts> loadKoreanPdfFonts() async {
  final r = await rootBundle.load(kPdfFontRegularAsset);
  final b = await rootBundle.load(kPdfFontBoldAsset);
  return KoreanPdfFonts(pw.Font.ttf(r), pw.Font.ttf(b));
}
