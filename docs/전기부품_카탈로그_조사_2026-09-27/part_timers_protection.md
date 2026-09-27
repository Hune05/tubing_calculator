# Timers and protection relays: front-view dimensions (mm)

Status: CONFIRMED = two different documents agree; SINGLE SOURCE = one; UNREAD = not read.
Values were read from drawings/text of the PDFs listed below (local copies in this folder). W x H = front face, D = behind panel/mounting surface unless noted.

## Timers

| Model | Front W x H | Depth | Panel cut-out | Front features | Status |
|---|---|---|---|---|---|
| Autonics AT8N (also AT11DN/AT11EN, same drawing) | 48 x 48 | 15 bezel + 50 body = 64.5 total, body 44.8 sq, plus pins/socket | 45 +0.6/0 sq, pitch min 65 | black face, round dial with 0-1 scale, POWER and OUT LEDs, time-unit and mode selector switches at bottom (A, A1, B, F, F1, I) | CONFIRMED for AT8N (catalog K-64 + instruction manual DRW171148AA both show 48/15/50/64.5/45); AT11DN/EN SINGLE (same page) |
| Autonics ATE (ATE/ATE1/ATE2 single range) | 48 x 48 | 14 bezel + 65 body = 80 incl pins; with PG-08 socket 86 total | 45 +0.6/0 sq, pitch min 55 x 65 | dial with MIN unit, PWR and UP LEDs, ATE-3M silk | SINGLE SOURCE (catalog K-77) |
| Autonics ATS8 / ATS11 (compact) | 38 x 42 | 8 bezel + 62 body = 75.5 incl pins | 45 +0.6/0 (bracket 48 sq) | round dial, POWER and OUT LEDs, MODE and RANGE switches | SINGLE SOURCE (catalog K-47) |
| Autonics AT8DN, ATM, LE8N | not found | | | | UNREAD (no source found; AT8N/AT11DN is the current model) |
| Autonics socket PG-08 (8 pin, plug-in) | 38 W x 41 H | 21 | none (rear mount) | black PBT, screw terminals | CONFIRMED (Autonics socket catalog p.26 + TME listing 38x41x21) |
| Autonics socket PG-11 (11 pin) | 45 x 43.4 | 21 | | | SINGLE SOURCE |
| Autonics socket PS-08 (DIN/panel) | 50 W x 70 H | 23.6 (body), rail height 35.3 | 2 holes dia 4.5 | blue release tab, screw terminals | SINGLE SOURCE |
| Autonics socket PS-11 (DIN/panel) | 50 x 70 | 31 (rail height 35.2) | 2 holes dia 4.5 | | SINGLE SOURCE |
| Hanyoung Nux T48N | 48 x 48 | 15 bezel + 78.7 = 93.7 total incl pins (body 63.7 + 15 pins), body 44.5 | 45 +0.5/0 sq, pitch 60 | black round dial 0-1, ON and UP LEDs, DIP for unit | SINGLE SOURCE (manual MD0401E) |
| Hanyoung Nux T38N | 40.5 x 50.5 | 9 bezel + 74 = 83 | 41.5 x 51.5 with 48 x 59 panel adaptor | dial, ON and UP LEDs | SINGLE SOURCE |
| Hanyoung Nux T48A | 48 x 48 | 59 | UNREAD | dial timer | SINGLE SOURCE (hanyoungnux.co.kr T48A page: 48.0 x 48.0 x 59.0) |
| Hanyoung Nux T57NP (panel type) | 57.5 x 84.4 | 100 total (74 behind flange) | 51 x 63 | dial, ON and UP LEDs | SINGLE SOURCE |

## Omron monitoring relays (DIN rail, 22.5 W)

| Model | W x H x D | Front features | Status |
|---|---|---|---|
| K8AK-PM1/2 (3-phase voltage, phase seq/loss) | 22.5 x 90 x 100 | ivory ABS (Munsell 5Y8/1), voltage and time knobs, power/relay (yellow) LEDs, alarm LED | CONFIRMED (K8AK-PM datasheet + K8AK/K8DS series datasheet n172x) |
| K8AK-PH1 (phase sequence/loss) | 22.5 x 90 x 100 | power and relay LEDs, no knob | SINGLE SOURCE (series datasheet: spec line + drawing) |
| K8AK-AS1/2/3 (1-phase current) | 22.5 x 90 x 100 | current knob (SV), startup lock time knob, power/relay/alarm LEDs | SINGLE SOURCE (series datasheet, drawing + spec) |
| K8AB-PW / PA / PM / AS (older series) | 22.5 x 90 x 100 | same body, ivory | SINGLE SOURCE (Omron N141 K8AB catalog; RS listing also gives 22.5 W and 100 D) |
| DIN rail height 90 within mounting, 35 mm rail; no panel cut-out (rail mounted) | | | |

## Samwha / Schneider EOCR (motor overcurrent relays)

| Model | W x H x D | Cut-out / mounting | Front features | Status |
|---|---|---|---|---|
| EOCR-3DM2 (window type) | 70 W x 74.5 H x 83.8 D | panel or DIN, hole pitch 82 x 95 (dia 4.5) | 7-segment LED, bar graph, reset/test, LED for phase, OL/NC output | CONFIRMED (Schneider datasheet 3DM2WRDUW + Schneider EOCR-DM2 catalog) |
| EOCR-FDM2 (flush display type) | 70 x 56.3 x 108.1 per catalog dimension table (drawing ambiguous) | flush mounting | display unit | SINGLE SOURCE, ambiguous |
| EOCR-SS-05S (easy type) | 70 W x 71 H x 68 D | 35 mm DIN or panel | 2 LEDs (PWR green, TRIP red), LOAD/D-TIME/O-TIME knobs, TEST/RESET button | SINGLE SOURCE (Schneider datasheet, copies at ple.vn/scribd are the same doc) |
| EOCR-3DM (older, 100A+ CT type) | 70 W x 53 H (+16 CT block) x 71 D, DIN | bracket hole 63 | 5-digit 7-seg LED, bar graph, DIP | SINGLE SOURCE (Samwha Korean catalog) |
| EOCR-FDM display unit | 72 x 72 (62 x 62 for S type), depth 39 (36) | cut-out dia 65 (dia 53) | 7-seg display, knob, PULL tab | SINGLE SOURCE |
| EOCR-DS, EOCR-AR | not found | | | UNREAD |

## LS ELECTRIC (LSIS) motor protection

| Model | W x H x D | Notes | Status |
|---|---|---|---|
| GMP60-3T/TR/TN (tunnel/screw) | 95.3 x 94.6 x 97 (drawing; 81 wide top plate, 37 mid) | black/grey body, 3 LEDs | CONFIRMED (LS EMPR catalog p.58 + Radwell listing 94.6 x 95 x 97) |
| GMP60T/TE/TA | about 72 W x 67 H x 69 D | 2 holes dia 13 | SINGLE SOURCE (LS EMPR catalog p.58) |
| GMP60-TD (display) | about 72.8 W x 75 H x 62 D | 4-digit LED | SINGLE SOURCE |
| GMP22-2P (1c) | 44 x 71.2 x 78 | | SINGLE SOURCE (catalog p.56) |
| GMP22-3P / 2P(1a1b) | 53 x 79.5 x 87.5 | | SINGLE SOURCE |
| GMP40-2P/3P | 53 x 78 x 87.5 | | SINGLE SOURCE |
| DMPi (integrated) | 76 W (68 body) x 94 H x 107 D | 82 mount width, DIN | SINGLE SOURCE (catalog p.31) |
| DMPi display panel insertion | 76 x 52, depth 44.6 + 19 | cut-out 55.5 x 20.5 as printed | SINGLE SOURCE, values look odd |

## Not found
- HD Hyundai Electric HIMAP dimensions: manuals located (scribd, pdfcoffee, kupdf) but the pages did not give dimensions. UNREAD.
- Autonics AT8DN, ATM, LE8N; Samwha EOCR-DS, EOCR-AR; SEL-710/751; ABB REJ/REF/REM, Sepam; Omron K8AK-PH own datasheet (only series datasheet read).

## Korea evidence
- Autonics: Busan, Korea maker (AT8N manual address); sold widely by Korean shops (danawa, misumi Korea, one-stop.co.kr).
- Hanyoung Nux: Incheon, Korea maker.
- EOCR: Samwha EOCR, now Schneider Electric Korea; Korean catalog and FAQ pages (se.com/kr).
- LS ELECTRIC GMP/DMP: Anyang, Korea maker.
- Omron K8AK: Korean use not verified.

## Sources
- Autonics ATN: https://autonics.se/wp-content/uploads/2018/03/atn_en_ca_ep_ke_02_053b_054b_20171121_he_20171128-1.pdf (K-64)
- AT8N INS: https://www.tme.eu/Document/efaac3753699dd4d325b7e7bb3b45870/AT8N-series-INS.pdf
- ATE: https://autonics.se/wp-content/uploads/2018/03/ATE_en_cat_150805.pdf (K-77); ATS: https://autonics.se/wp-content/uploads/2018/03/ats8_11_en_ca_drw161278ab_20171121_he_20171128.pdf (K-47)
- Sockets: https://www.instrumart.com/assets/Autonics-Sockets-datasheet.pdf (p.26); https://www.tme.com/us/en-us/details/pg-08/timers-accessories/autonics/
- Hanyoung: https://www.ssint.com.mx/manuales/Manual_T38N_T48N_T57N_TF62N_TF62D.pdf (p.3); https://hanyoungnux.co.kr/product/product_view.php?num=342&lcode=01&mcode=0104&pcode=2302100002&scode=0104005
- Omron: https://airlinemedia.airlinehyd.com/Literature/Manufacturer_Catalogs/Omron/Datasheets/K8AK-PM_DataSheet.pdf ; https://files.omron.eu/downloads/latest/datasheet/en/n172x_k8ak_k8ds-series_measuring_monitoring_relays_datasheet_en.pdf ; https://edata.omron.com.au/eData/LVSG/N141-E1-01.pdf
- EOCR: https://thietbidienschneider.com.vn/wp-content/uploads/2023/03/Catalog-EOCR-3DM2-EOCR-FDM2-EOCR-3MZ2-EOCR-FMZ2-Schneider.pdf (p.39, 48-50); https://alliance-a.com/pdf/datasheet/EOCR-3DM2-WRDUW.pdf ; https://eocrsek.co.kr/eocr/pdf/EOCR_3DMFDM.pdf (p.4); https://ple.vn/images/virtuemart/datasheet/5348-eocrss-05s.pdf
- LS: https://www.ls-electric.com/upload/customer/download/2601/EMPR%20Series_E_09-1909.pdf (p.31, 56-58); Radwell GMP60-3TNR listing
