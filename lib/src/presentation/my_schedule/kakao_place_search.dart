import 'dart:convert';

import 'package:http/http.dart' as http;

// 카카오 로컬 API로 장소를 이름으로 찾는다("중부발전" → 이름 + 주소 + 좌표).
//
// 키는 저장소에 넣지 않는다(이 저장소는 GitHub에 공개되어 있다). 빌드할 때 넘긴다:
//   . tool/keys.local.sh && flutter build apk --debug --dart-define=KAKAO_REST_KEY=$KAKAO_REST_KEY
// 키가 없으면 검색은 쓸 수 없다고 알려 주고, 장소 이름만 적어 지도로 찾는 방식은 그대로 쓸 수 있다.
const String kKakaoRestKey = String.fromEnvironment('KAKAO_REST_KEY');

bool get hasKakaoKey => kKakaoRestKey.trim().isNotEmpty;

class KakaoPlace {
  final String name;
  final String address; // 도로명 주소가 있으면 그것, 없으면 지번 주소
  final double? lat;
  final double? lng;
  final String phone;

  const KakaoPlace({
    required this.name,
    required this.address,
    this.lat,
    this.lng,
    this.phone = '',
  });
}

// 카카오 응답(JSON)을 목록으로 바꾼다. 화면과 통신에서 떼어 놓아 테스트로 지킨다.
List<KakaoPlace> parseKakaoPlaces(String body) {
  final Map<String, dynamic> map = jsonDecode(body) as Map<String, dynamic>;
  final List docs = (map['documents'] as List?) ?? const [];
  final out = <KakaoPlace>[];
  for (final d in docs) {
    if (d is! Map) continue;
    final name = (d['place_name'] as String?)?.trim() ?? '';
    if (name.isEmpty) continue;
    final road = (d['road_address_name'] as String?)?.trim() ?? '';
    final jibun = (d['address_name'] as String?)?.trim() ?? '';
    out.add(
      KakaoPlace(
        name: name,
        address: road.isNotEmpty ? road : jibun,
        lat: double.tryParse((d['y'] as String?) ?? ''),
        lng: double.tryParse((d['x'] as String?) ?? ''),
        phone: (d['phone'] as String?)?.trim() ?? '',
      ),
    );
  }
  return out;
}

class KakaoSearchException implements Exception {
  final String message;
  const KakaoSearchException(this.message);
  @override
  String toString() => message;
}

// 이름으로 장소를 찾는다(최대 [size]개). 키가 없거나 통신이 막히면 KakaoSearchException.
Future<List<KakaoPlace>> searchKakaoPlaces(
  String query, {
  int size = 12,
}) async {
  final q = query.trim();
  if (q.isEmpty) return const [];
  if (!hasKakaoKey) {
    throw const KakaoSearchException(
      "카카오 키가 없어 주소 검색을 쓸 수 없습니다. 장소 이름만 적어 두고 지도 단추로 찾으십시오.",
    );
  }
  final uri = Uri.https('dapi.kakao.com', '/v2/local/search/keyword.json', {
    'query': q,
    'size': '$size',
  });
  try {
    final res = await http.get(
      uri,
      headers: {'Authorization': 'KakaoAK $kKakaoRestKey'},
    );
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw const KakaoSearchException(
        "카카오 키가 거부되었습니다(권한). 개발자 콘솔에서 키와 플랫폼 설정을 확인하십시오.",
      );
    }
    if (res.statusCode != 200) {
      throw KakaoSearchException("장소를 찾지 못했습니다 (오류 ${res.statusCode}).");
    }
    return parseKakaoPlaces(utf8.decode(res.bodyBytes));
  } on KakaoSearchException {
    rethrow;
  } catch (e) {
    throw KakaoSearchException("장소를 찾지 못했습니다: $e");
  }
}
