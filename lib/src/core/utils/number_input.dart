// 사람이 넣은 수를 읽는다. 🚀 [고침] "6,000"이나 "6000mm"를 넣으면 숫자로 못 읽어
// 0으로 저장되거나 말없이 무시됐다. 자릿점·띄어쓰기·끝의 단위 글자는 빼고 읽는다.
library;

final RegExp _unitTail = RegExp(r'(mm|개|본|ea|EA|Ea)$');

String _clean(String text) => text
    .trim()
    .replaceAll(',', '')
    .replaceAll(' ', '')
    .replaceFirst(_unitTail, '');

/// 정수로 읽는다. 숫자가 아니면(빈칸 포함) null.
int? parseIntInput(String text) => int.tryParse(_clean(text));

/// 소수로 읽는다. 숫자가 아니면(빈칸 포함) null.
double? parseNumInput(String text) => double.tryParse(_clean(text));
