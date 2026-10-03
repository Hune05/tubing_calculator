// 원인 확인: 계산기 입력을 받아 원인 후보와 "고치면 얼마가 되는지"를 계산한다(10-03).
// 모든 숫자는 elec_calc.dart의 계산 함수로 다시 계산한 값이다. 새 기준값은 만들지 않고,
// 현장 점검 항목(측정 위치·확인 방법)은 설비 점검의 일반 절차만 적는다.
library;

import 'diagnosis_page.dart';
import 'elec_calc.dart';
import 'elec_form_parts.dart';
import 'elec_tables.dart';

/// 전압강하가 한도를 넘을 때 원인 후보.
/// [startMult]·[startPf]·[startLimit]을 주면 기동 시 초과도 다룬다(없으면 정상 운전만).
DiagCase voltageDropDiagnosis({
  required double current,
  required double lengthM,
  required double size,
  required Phase phase,
  required double pf,
  required double volts,
  required Insulation ins,
  required SupplyType supply,
  required double reservedPct,
  required List<(String, String)> inputs,
  double? startMult,
  double? startPf,
  double? startLimitPct,
  bool startMultIsDirect = false,
  Conductor conductor = Conductor.copper,
}) {
  final temp = conductorTemp(ins);
  double pctOf({double? i, double? len, double? sz, double? p}) =>
      voltageDrop(
        current: i ?? current,
        lengthM: len ?? lengthM,
        size: sz ?? size,
        phase: phase,
        pf: p ?? pf,
        conductorTempC: temp,
        conductor: conductor,
      ) /
      volts *
      100;

  final limit = voltageDropLimit(supply, lengthM);
  final pct = pctOf();
  final total = pct + reservedPct;
  final room = limit - reservedPct;
  final sizes = conductor == Conductor.aluminum
      ? List<double>.of(kAlSizes)
      : (kCuR20.keys.toList()..sort());
  final causes = <DiagCause>[];

  // 1. 입력한 전류 (확인하기 가장 쉽다)
  causes.add(
    DiagCause(
      title: '입력한 전류가 실제와 다르다',
      check: '명판 정격전류, 설계전류(정격 × 여유율), 실측 전류 중 어느 값을 넣었는지 확인합니다. 여유율을 곱한 값을 넣었다면 전압강하에는 실제 부하 전류를 씁니다.',
      effect: room > 0
          ? '이 굵기·길이에서 한도 안에 들려면 전류가 약 ${fmt(current * room / pct, 1)} A 이하여야 합니다(입력 ${fmt(current, 1)} A).'
          : '전원 쪽에서 이미 ${fmt(reservedPct, 2)} %를 써서 이 구간에 남은 한도가 없습니다.',
      basis: '전압강하는 전류에 비례합니다(ΔU = k × I × L × (R cosφ + X sinφ)).',
    ),
  );

  // 2. 길이
  final maxLen = maxLengthForDrop(
    current: current,
    size: size,
    phase: phase,
    volts: volts,
    pf: pf,
    conductorTempC: temp,
    supply: supply,
    reservedPct: reservedPct,
    conductor: conductor,
  );
  causes.add(
    DiagCause(
      title: '길이가 실제보다 길게 들어갔거나, 정말 길다',
      check: '도면 길이와 실제 포설 경로(수직 구간·여유 길이 포함)를 비교합니다. 편도 길이를 넣었는지(왕복 길이를 넣으면 2배가 됩니다) 확인합니다.',
      effect: maxLen == null
          ? null
          : '이 굵기·전류에서는 편도 약 ${fmt(maxLen, 0)} m까지 한도 안입니다(입력 ${fmt(lengthM, 0)} m).',
      basis: '한도는 100 m를 넘는 길이에 1 m당 0.005 %를 더해 최대 0.5 %까지 허용합니다(KEC 232.3.9).',
    ),
  );

  // 3. 역률
  if (phase != Phase.dc) {
    final hi = pctOf(p: 0.95), lo = pctOf(p: 0.70);
    causes.add(
      DiagCause(
        title: '입력한 역률이 실제와 다르다',
        check: '부하 명판 역률이나 역률계 값을 확인합니다. 전동기는 부하가 작을수록 역률이 낮습니다.',
        effect:
            '역률 0.95로 넣으면 ${fmt(hi, 2)} %, 0.70이면 ${fmt(lo, 2)} %입니다(입력 ${fmt(pf, 2)}: ${fmt(pct, 2)} %).',
        basis: '굵은 전선일수록 리액턴스 항이 커서 역률 영향이 달라집니다.',
      ),
    );
  }

  // 4. 굵기
  double? needSize;
  double? needPct;
  for (final s in sizes) {
    if (s <= size) continue;
    final p = pctOf(sz: s);
    if (p + reservedPct <= limit + 1e-9) {
      needSize = s;
      needPct = p;
      break;
    }
  }
  causes.add(
    DiagCause(
      title: '실제로 포설된 전선이 도면 굵기와 다르다, 또는 굵기가 모자란다',
      check: '케이블 표면 표기나 시험성적서로 단면적을 확인합니다. 계장·제어용 0.75·1.5 sq가 섞여 있지 않은지 봅니다.',
      effect: needSize != null
          ? '${sqText(needSize)}로 올리면 ${fmt(needPct!, 2)} %로 한도 ${fmt(limit, 2)} % 안에 듭니다(현재 ${sqText(size)}: ${fmt(pct, 2)} %).'
          : '표에 있는 가장 굵은 전선(${sqText(sizes.last)})으로도 한도를 넘습니다. 길이·전류·전원 쪽 강하를 먼저 줄이십시오.',
    ),
  );

  // 5. 전원 쪽 강하
  if (reservedPct > 0) {
    causes.add(
      DiagCause(
        title: '전원 쪽에서 이미 쓴 전압강하 입력이 크다',
        check: '변압기·간선 구간의 전압강하 값(${fmt(reservedPct, 2)} %)이 실제 계산값과 같은지 확인합니다. 한도는 수전점부터 기기까지 합계입니다.',
        effect: '이 구간 전압강하 ${fmt(pct, 2)} % + 전원 쪽 ${fmt(reservedPct, 2)} % = ${fmt(total, 2)} %, 한도 ${fmt(limit, 2)} %.',
      ),
    );
  }

  // 6. 기동 시
  if (startMult != null && startPf != null && startLimitPct != null) {
    final sPct = pctOf(i: current * startMult, p: startPf) + reservedPct;
    if (sPct > startLimitPct + 1e-9) {
      double? sSize;
      double? sSizePct;
      for (final s in sizes) {
        if (s <= size) continue;
        final p = pctOf(i: current * startMult, p: startPf, sz: s);
        if (p + reservedPct <= startLimitPct + 1e-9) {
          sSize = s;
          sSizePct = p + reservedPct;
          break;
        }
      }
      final yd = pctOf(i: current * startMult / 3, p: startPf) + reservedPct;
      causes.add(
        DiagCause(
          title: '기동 중 전압강하가 허용 한도를 넘는다',
          check: '기동 전류 배수(직입 5~8배 등)와 기동 방식을 확인합니다. 기동 중 전동기 단자 전압이 모자라면 기동이 안 되거나 오래 걸립니다.',
          effect:
              '기동 시 현재 ${fmt(sPct, 2)} %(허용 ${fmt(startLimitPct, 2)} %). ${startMultIsDirect ? "" : "Y-Δ 기동(직입의 1/3 전류)이면 ${fmt(yd, 2)} %. "}${sSize != null ? "굵기를 ${sqText(sSize)}로 올리면 ${fmt(sSizePct!, 2)} %." : "표의 최대 굵기로도 초과합니다."}',
          basis: '기동 중 전압강하는 정상 운전 한도보다 큰 값을 허용할 수 있습니다(KEC 232.3.9의 2 가). 허용 한도는 사용자가 입력한 값입니다.',
        ),
      );
    }
  }

  // 7. 접속부 (계산이 아니라 현장 확인)
  causes.add(
    const DiagCause(
      title: '계산은 맞는데 실측 전압강하가 더 크다',
      check:
          '전원 쪽과 부하 단자에서 같은 시각에 부하 운전 중 전압을 측정해 차이를 봅니다. 계산보다 크게 나오면 단자 조임 불량·접속부 발열·전선 열화를 의심하고, 접속부 온도를 열화상이나 접촉식으로 확인합니다.',
    ),
  );

  return DiagCase(
    title: '전압강하 원인 확인',
    symptom:
        '전압강하율 ${fmt(total, 2)} %가 한도 ${fmt(limit, 2)} %를 초과합니다',
    inputs: inputs,
    causes: causes,
    footer: '위 계산은 전압강하 탭과 같은 식입니다. 고친 값을 계산기에 다시 넣어 확인하십시오. 최종 판단은 설계 도서와 현장 실측으로 하십시오.',
  );
}

/// 기존 회로 점검이 불합격일 때 원인 후보. [rerun]은 같은 조건에서 일부 값만 바꿔 다시 점검한다.
DiagCase circuitCheckDiagnosis({
  required CircuitCheck k,
  required CircuitCheck Function({
    double? size,
    int? circuits,
    double? ambientC,
    int? breaker,
    int? parallel,
  })
  rerun,
  required double baseAmbientC,
  required double ambientC,
  required int circuits,
  required List<(String, String)> inputs,
}) {
  final causes = <DiagCause>[];
  final sizes = k.conductor == Conductor.aluminum ? kAlSizes : kCableSizes;
  final iz = k.iz;
  final ib = k.ib;
  final b = k.breaker;
  final symptoms = <String>[];
  if (k.ibOk == false) {
    symptoms.add(
      b == null
          ? '설계전류 IB ${fmt(ib!, 1)} A가 허용전류 IZ ${fmt(iz!, 1)} A를 초과합니다'
          : '설계전류 IB ${fmt(ib!, 1)} A가 차단기 In $b A를 초과합니다',
    );
  }
  if (k.inOk == false) {
    symptoms.add('차단기 In $b A가 허용전류 IZ ${fmt(iz!, 1)} A를 초과합니다');
  }
  final dropOver =
      k.dropPct != null && k.dropPct! > k.dropLimitPct + 1e-9;
  if (dropOver) {
    symptoms.add(
      '전압강하율 ${fmt(k.dropPct!, 2)} %가 한도 ${fmt(k.dropLimitPct, 2)} %를 초과합니다',
    );
  }

  // In > IZ
  if (k.inOk == false && iz != null && b != null) {
    final lower = breakerAtMost(iz);
    causes.add(
      DiagCause(
        title: '차단기 정격이 전선 허용전류보다 크다',
        check: '차단기 명판 정격과 현장 설정(조정형이면 설정값)을 확인합니다. 설계 도서의 정격과 같은지 봅니다.',
        effect: lower == null
            ? null
            : (ib != null && lower >= ib - 1e-9
                  ? '차단기를 $lower A로 낮추면 IB ${fmt(ib, 1)} ≤ In $lower ≤ IZ ${fmt(iz, 1)} A로 만족합니다.'
                  : '허용전류 이하의 표준 차단기는 $lower A인데 설계전류 ${fmt(ib ?? 0, 1)} A보다 작아, 차단기만 낮춰서는 해결되지 않습니다.'),
        basis: 'IB ≤ In ≤ IZ (KEC 212.4.1).',
      ),
    );
  }
  if (k.ibOk == false && ib != null) {
    final up = breakerFor(ib);
    causes.add(
      DiagCause(
        title: '설계전류가 차단기 정격보다 크다(부하가 커졌거나 입력이 크다)',
        check: '부하 전류 입력과 여유율(전동기 1.25배 등)을 확인합니다. 부하가 늘었다면 실측 전류를 측정합니다.',
        effect: up == null
            ? null
            : '차단기를 $up A 이상으로 하려면 허용전류 IZ가 $up A 이상이어야 합니다(현재 IZ ${fmt(iz ?? 0, 1)} A).',
        basis: 'IB ≤ In (KEC 212.4.1).',
      ),
    );
  }

  // IZ를 줄이는 보정
  if (k.inOk == false || k.ibOk == false) {
    if (circuits > 1 && k.groupFactor < 1 - 1e-9) {
      final r = rerun(circuits: 1);
      if (r.iz != null) {
        causes.add(
          DiagCause(
            title: '같이 포설된 회로 수가 실제보다 많이 잡혔다',
            check: '같은 관·트레이·덕트에 실제로 함께 포설된 회로를 도면과 현장에서 세어 봅니다. 입력은 $circuits회로입니다.',
            effect:
                '회로 수를 1로 보면 다조 보정 ${fmt(k.groupFactor, 2)} → ${fmt(r.groupFactor, 2)}, IZ ${fmt(iz ?? 0, 1)} → ${fmt(r.iz!, 1)} A.',
            basis: '허용전류 = 표 값 × 온도 보정 × 다조 포설 보정(IEC 60364-5-52).',
          ),
        );
      }
    }
    if (k.tempFactor > 0 && k.tempFactor < 1 - 1e-9) {
      final r = rerun(ambientC: baseAmbientC);
      if (r.iz != null) {
        causes.add(
          DiagCause(
            title: '주위 온도 입력이 실제보다 높다',
            check: '설치 위치의 실제 온도를 측정합니다(보일러실·덕트 안은 높습니다). 입력은 ${fmt(ambientC)} ℃, 표 기준은 ${fmt(baseAmbientC)} ℃입니다.',
            effect:
                '기준 온도에서는 보정 ${fmt(k.tempFactor, 2)} → ${fmt(r.tempFactor, 2)}, IZ ${fmt(iz ?? 0, 1)} → ${fmt(r.iz!, 1)} A.',
            basis: '높은 주위 온도는 허용전류를 줄입니다(표 B.52.14·15).',
          ),
        );
      }
    }
  }

  // 굵기
  if (k.inOk == false || k.ibOk == false || dropOver) {
    double? s;
    CircuitCheck? sr;
    for (final cand in sizes) {
      if (cand <= k.size) continue;
      final r = rerun(size: cand);
      final okIz = r.inOk != false && r.ibOk != false;
      final okDrop = r.dropPct == null || r.dropPct! <= r.dropLimitPct + 1e-9;
      if (okIz && okDrop) {
        s = cand;
        sr = r;
        break;
      }
    }
    causes.add(
      DiagCause(
        title: '실제 전선 굵기가 도면과 다르다, 또는 굵기가 모자란다',
        check: '케이블 표기나 시험성적서로 단면적을 확인합니다. 병렬 포설이면 가닥 수와 가닥당 굵기를 확인합니다.',
        effect: s == null
            ? '표에 있는 굵기로는 해결되지 않습니다. 병렬·포설 방법·부하를 다시 검토하십시오.'
            : '${sqText(s)}로 올리면 IZ ${fmt(sr!.iz ?? 0, 1)} A${sr.dropPct == null ? "" : ", 전압강하율 ${fmt(sr.dropPct!, 2)} %"}로 모두 만족합니다(현재 ${sqText(k.size)}: IZ ${fmt(iz ?? 0, 1)} A).',
      ),
    );
    if (k.parallel == 1 && k.size >= parallelMinSize(k.conductor)) {
      final r = rerun(parallel: 2);
      if (r.iz != null) {
        causes.add(
          DiagCause(
            title: '한 가닥으로 모자라면 병렬로 나눌 수 있다',
            check: '병렬은 같은 도체·재료·길이·굵기로 해야 하고 가닥마다 퓨즈를 달지 않습니다(KEC 123).',
            effect: '2가닥 병렬이면 IZ ${fmt(iz ?? 0, 1)} → ${fmt(r.iz!, 1)} A.',
            basis: '병렬 전선은 구리 50 mm² 이상(KEC 123의 6 가).',
          ),
        );
      }
    }
  }

  causes.add(
    const DiagCause(
      title: '포설 방법 입력이 실제와 다르다',
      check: '관 속·트레이·지중 등 실제 포설 방법이 입력과 같은지 확인합니다. 방법에 따라 같은 굵기라도 허용전류 표 값이 달라집니다.',
    ),
  );

  return DiagCase(
    title: '기존 회로 원인 확인',
    symptom: symptoms.isEmpty ? '점검 결과가 불합격입니다' : symptoms.join(' · '),
    inputs: inputs,
    causes: causes,
    footer: '위 계산은 전선 굵기 탭의 기존 회로 점검과 같은 식입니다. 최종 판단은 설계 도서와 현장 실측으로 하십시오.',
  );
}
