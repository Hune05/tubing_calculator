# Firestore 권한 규칙 시험

`firestore.rules`를 에뮬레이터에 올려 "내 것·공용" 규칙(점검 25·26번)을 확인한다.
Java와 Node가 있어야 한다.

```
cd tool/firestore_rules_test
npm install
npm test
```

마지막 줄에 `통과 N 실패 0`이 나오면 된다. 규칙을 콘솔에 올리기 전에 돌린다.
