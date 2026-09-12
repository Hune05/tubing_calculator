// lib/src/data/models/bender_spec_data.dart

/// 강제 전선관(KS 규격: 16, 22, 28, 36, 42, 54) 기준 장비 실제 제원 데이터
const Map<String, Map<String, Map<String, Map<String, Map<String, dynamic>>>>>
benderSpecData = {
  // 1. 수동 벤더 (Hand Bender)
  'hand': {
    'Greenlee': {
      'EMT': {
        '16mm': {'takeUp': 127.0, 'gain': 66.7, 'clr': 101.6},
        '22mm': {'takeUp': 152.4, 'gain': 82.5, 'clr': 114.3},
        '28mm': {'takeUp': 203.2, 'gain': 101.6, 'clr': 146.0},
        '36mm': {'takeUp': 279.4, 'gain': 142.8, 'clr': 184.1},
        '42mm': {'takeUp': 304.8, 'gain': 160.0, 'clr': 209.5},
        '54mm': {'takeUp': 355.6, 'gain': 180.0, 'clr': 241.3},
      },
      'Rigid': {
        '16mm': {'takeUp': 152.4, 'gain': 82.5, 'clr': 114.3},
        '22mm': {'takeUp': 203.2, 'gain': 101.6, 'clr': 146.0},
        '28mm': {'takeUp': 279.4, 'gain': 142.8, 'clr': 184.1},
        '36mm': {'takeUp': 304.8, 'gain': 160.0, 'clr': 209.5},
        '42mm': {'takeUp': 355.6, 'gain': 180.0, 'clr': 241.3},
        '54mm': {'takeUp': 406.4, 'gain': 200.0, 'clr': 280.0},
      },
    },
    'Ideal': {
      'EMT': {
        '16mm': {'takeUp': 127.0, 'gain': 66.7, 'clr': 101.6},
        '22mm': {'takeUp': 152.4, 'gain': 82.5, 'clr': 114.3},
        '28mm': {'takeUp': 203.2, 'gain': 101.6, 'clr': 146.0},
        '36mm': {'takeUp': 279.4, 'gain': 142.8, 'clr': 184.1},
        '42mm': {'takeUp': 304.8, 'gain': 160.0, 'clr': 209.5},
        '54mm': {'takeUp': 355.6, 'gain': 180.0, 'clr': 241.3},
      },
    },
  },

  // 2. 유압식 벤더 (Ram Bender) - 16mm, 22mm도 강제 추가하여 에러 방지
  // (ramOffset은 setback과 항상 동일한 값이라 중복 필드라 제거함)
  'ram': {
    'Greenlee': {
      'Rigid': {
        '16mm': {'ramTravel': 100.0, 'setback': 150.0, 'clr': 101.6},
        '22mm': {'ramTravel': 120.0, 'setback': 175.0, 'clr': 114.3},
        '28mm': {'ramTravel': 142.8, 'setback': 203.2, 'clr': 146.0},
        '36mm': {'ramTravel': 177.8, 'setback': 254.0, 'clr': 184.1},
        '42mm': {'ramTravel': 203.2, 'setback': 304.8, 'clr': 209.5},
        '54mm': {'ramTravel': 234.9, 'setback': 355.6, 'clr': 241.3},
      },
      'EMT': {
        '16mm': {'ramTravel': 100.0, 'setback': 150.0, 'clr': 101.6},
        '22mm': {'ramTravel': 120.0, 'setback': 175.0, 'clr': 114.3},
        '28mm': {'ramTravel': 142.8, 'setback': 203.2, 'clr': 146.0},
        '36mm': {'ramTravel': 177.8, 'setback': 254.0, 'clr': 184.1},
        '42mm': {'ramTravel': 203.2, 'setback': 304.8, 'clr': 209.5},
        '54mm': {'ramTravel': 234.9, 'setback': 355.6, 'clr': 241.3},
      },
    },
    'Current Tools': {
      'Rigid': {
        '16mm': {'ramTravel': 98.0, 'setback': 145.0, 'clr': 100.0},
        '22mm': {'ramTravel': 118.0, 'setback': 170.0, 'clr': 115.0},
        '28mm': {'ramTravel': 140.0, 'setback': 200.0, 'clr': 145.0},
        '36mm': {'ramTravel': 175.0, 'setback': 250.0, 'clr': 185.0},
        '42mm': {'ramTravel': 200.0, 'setback': 300.0, 'clr': 210.0},
        '54mm': {'ramTravel': 235.0, 'setback': 350.0, 'clr': 240.0},
      },
    },
  },

  // 3. 시카고식 벤더 (Chicago/Rotary)
  // takeUp: 시카고식도 수동 벤더와 동일한 슈(관 반경) 구조를 기어로 돌리는
  // 방식이라, 같은 제조사/규격의 수동 벤더 테이크업 값을 그대로 적용함(근사치).
  'chicago': {
    'Greenlee': {
      'Rigid': {
        '16mm': {
          'degPerNotch': 2.0,
          'notchSpacing': 40.0,
          'rollerSize': 38.1,
          'clr': 101.6,
          'takeUp': 152.4,
        },
        '22mm': {
          'degPerNotch': 2.5,
          'notchSpacing': 50.8,
          'rollerSize': 38.1,
          'clr': 114.3,
          'takeUp': 203.2,
        },
        '28mm': {
          'degPerNotch': 3.0,
          'notchSpacing': 60.0,
          'rollerSize': 45.0,
          'clr': 146.0,
          'takeUp': 279.4,
        },
        '36mm': {
          'degPerNotch': 3.5,
          'notchSpacing': 70.0,
          'rollerSize': 50.0,
          'clr': 184.1,
          'takeUp': 304.8,
        },
        '42mm': {
          'degPerNotch': 4.0,
          'notchSpacing': 80.0,
          'rollerSize': 55.0,
          'clr': 209.5,
          'takeUp': 355.6,
        },
        '54mm': {
          'degPerNotch': 4.5,
          'notchSpacing': 90.0,
          'rollerSize': 60.0,
          'clr': 241.3,
          'takeUp': 406.4,
        },
      },
      'EMT': {
        '16mm': {
          'degPerNotch': 2.0,
          'notchSpacing': 40.0,
          'rollerSize': 38.1,
          'clr': 101.6,
          'takeUp': 127.0,
        },
        '22mm': {
          'degPerNotch': 2.5,
          'notchSpacing': 50.8,
          'rollerSize': 38.1,
          'clr': 114.3,
          'takeUp': 152.4,
        },
        '28mm': {
          'degPerNotch': 3.0,
          'notchSpacing': 60.0,
          'rollerSize': 45.0,
          'clr': 146.0,
          'takeUp': 203.2,
        },
        '36mm': {
          'degPerNotch': 3.5,
          'notchSpacing': 70.0,
          'rollerSize': 50.0,
          'clr': 184.1,
          'takeUp': 279.4,
        },
        '42mm': {
          'degPerNotch': 4.0,
          'notchSpacing': 80.0,
          'rollerSize': 55.0,
          'clr': 209.5,
          'takeUp': 304.8,
        },
        '54mm': {
          'degPerNotch': 4.5,
          'notchSpacing': 90.0,
          'rollerSize': 60.0,
          'clr': 241.3,
          'takeUp': 355.6,
        },
      },
    },
  },
};
