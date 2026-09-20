# 자재 목록 긁어오기

`lib/src/presentation/inventory/material_catalog_vendor.dart`를 만드는 도구다.
자료는 경진전기(https://kjshop.kr) 상품 목록에서 가져온다 — 전선관·후렉시블·부속의
상품 이름과 규격(옵션)을 그대로 읽는다.

## 다시 돌리는 방법

```bash
cd tool/material_catalog
node scrape_kjshop.js vendor.json
```

```bash
cd tool/material_catalog
node to_dart.js ../../lib/src/presentation/inventory/material_catalog_vendor.dart
```

`cats.json`이 어느 칸을 읽을지 정한다. 한 줄 = [카테고리 아이디, 앱 분류, 갈래, 단위].
카테고리 아이디는 업체 사이트 주소의 `ps_ctid` 값이다. 읽는 데 몇 분 걸린다
(상품마다 규격 목록을 따로 받아 온다).

돌린 뒤에는 `flutter test test/material_catalog_test.dart`로 확인하고, 앱에서
자재 목록 화면 ⋮ → "기본 목록 채우기"를 눌러 서버에 새로 생긴 자재를 채운다.
이미 있는 자재는 건드리지 않으니 고쳐 놓은 이름은 그대로 남는다.
