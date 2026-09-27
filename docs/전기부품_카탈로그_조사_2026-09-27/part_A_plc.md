# Part A: PLC I/O modules and bases, front dimensions (mm)

Rules: confirmed = 2 independent documents agree. single = one document. Order of axes is as stated by the source.
Working files: C:\Users\gnsl5\AppData\Local\Temp\elec_parts2\w2\ (downloaded PDFs).
Note: the WebSearch budget ran out during the run, so the second source for several LS Electric items could not be searched for.

## 1. LS Electric XGT

| item | W x H x D mm | status | front features | source | Korea evidence |
|---|---|---|---|---|---|
| XGT CPU (XGI-CPUU / XGK-CPUU class) | 27 x 98 x 90 | single source (catalog states "CPU 27X98X90, Size(WXHXD)") | slim housing, same as I/O | XGT catalog XGT_E_180905.pdf p.4-5 https://www.ls-electric.com/upload/customer/download/c85f50f9-df09-48bb-837e-73f098a30d74/XGT_E_180905.pdf | LS Electric is Korean; manual/catalog on ls-electric.com |
| XGT I/O module, 32-pt DC24V slim type. Confirmed for XGF-SOEA event input module. Not XGI-D24A itself | 27 x 98 x 90 | confirmed for the XGF-SOEA (catalog line "27x98x90" + XGI-CPU manual "Size 27x98x90"). For XGI-D24A / XGQ-TR2A / XGF-AD8A: NOT READABLE (no size line in text, drawing is an image) | 40-pin connector, "LED on with input on", weight 0.2 kg | XGI-CPU manual V2.3 sect.7.5.1 https://sol.ls-electric.com/uploads/document/17592011682480/Manual_XGI-CPU_202508_V2.3_EN.pdf ; XGT catalog (SOEA spec table) | same as above |
| XGT communication module (FEnet etc.) | 27 (W) x 98 (H) x 90 (D) | single source (catalog states "98(H)27(W)90(D)"). One other comm module is stated as 18(H)x120(W)x174(D), not a plug-in module | | XGT catalog | same |
| XGT power module (XGP-ACF2 / AC23 ...) | 55 x 98 x 90 | single source (catalog "Power Supply 55X98X90", model not named). Manual Appendix 2 has table "A(mm)": XGP-ACF1/ACF2/DC42 = 90; XGP-AC23/AC24/14 = 110; XGP-SAC24/DC44 = 130. Drawing not readable, so what A means (probably depth) is not proven | | XGT catalog; XGI-CPU manual Appendix 2 | same |
| Main base XGB-M04A / M06A / M08A / M10A / M12A | 210 / 264 / 318 / 375 / 426 x 98 x 19 (slots 4/6/8/10/12) | manual states it directly; catalog says 8-slot 318X98X17. Width and height agree, depth differs (19 vs 17): width x height confirmed, depth NOT confirmed (use 17 or 19) | mounting hole distance 190/244/298/355/406 x 75, hole 4.5 mm (M4). Extension base XGB-E04A..E12A same sizes (M10 has none) | XGI-CPU manual sect.9.1 (page A2-3 table A/B); XGT catalog p.4-5 | same |
| Battery | 17.0 x 33.5 (dia x length) | single | | XGI-CPU manual 4.3.1 | |
| XGT Remote (XGR/XEC-remote, GPL/GEL series) | | not found | | | |

Front feature source for LS: LED row and connector notes only from the SOEA table. Colour of the housing, latch and label slot are not in the text documents (not readable).

## 2. Siemens SIMATIC S7-1500 / ET 200SP / ET 200M

Source A = Siemens TED data sheet (apim.industry.siemens.cloud/ted/datasheet?format=pdf&mlfbs=<MLFB>). Source B = Baldwin Supply distributor page https://www.baldwinsupply.com/itemdetail/<MLFB without dashes>, with the stated label "H x W x D". Note: rs-online docs.rs-online.com/5cf1/A700000006979151.pdf is only a mirror of the same Siemens data sheet, not counted.

| item | W x H x D mm | status | front features | source | Korea evidence |
|---|---|---|---|---|---|
| CPU 1511-1 PN 6ES7511-1AK02-0AB0 | 35 x 147 x 129 | confirmed (A + B "147 H x 35 W x 129 D") | 1 memory card slot, PROFINET, Industrial Ethernet status LED; display exists (data sheet "Display" section) | TED data sheet; baldwinsupply.com/itemdetail/6ES75111AK020AB0 | data sheet lists KR (Korean Register) approval |
| CPU 1516-3 PN/DP 6ES7516-3AN02-0AB0 | 70 x 147 x 129 | single source (Baldwin page has no dimensions) | 2 PN interfaces + 1 PROFIBUS | TED data sheet | same |
| PS 25W 24VDC 6ES7505-0KA00-0AB0 | 35 x 147 x 129 | confirmed. Baldwin labels swapped (H147 W129 D35), TED says Width 35 Height 147 Depth 129 | | TED; Baldwin 6ES75050KA000AB0 | same |
| PS 60W 24/48/60VDC 6ES7505-0RA00-0AB0 | 70 x 147 x 129 | confirmed (TED + Baldwin page for 6ES75050RA000AB0 "147 H x 70 W x 129 D") | | TED; baldwinsupply.com/itemdetail/6ES75050RA000AB0 | same |
| PS 60W 120/230V AC/DC 6ES7507-0RA00-0AB0 | 70 x 147 x 129 | single source (TED) | | TED | same |
| PM 1507 24V/3A 6EP1332-4BA00 (this is the 70 W-class module; not exactly "PM 70W 120/230") | 50 x 147 x 129 | single source (TED, "width x height x depth 50 x 147 x 129 mm") | | TED | same |
| PM 1507 24V/8A 6EP1333-4BA00 | 75 x 147 x 129 | single source (TED) | | TED | same |
| DI 16x24VDC HF 6ES7521-1BH00-0AB0 (35 mm class) | 35 x 147 x 129 | confirmed (TED + Baldwin "147 H x 35 W x 129 D") | LEDs: RUN green, ERROR red, PWR green, per-channel green, red channel/module diagnostics; front connector (screw or push-in) ordered separately | TED; baldwinsupply.com/itemdetail/6ES75211BH000AB0 | same |
| DQ 16x24VDC/0.5A HF 6ES7522-1BH01-0AB0 | 35 x 147 x 129 | single source (TED) | same family | TED | |
| DI 32x24VDC HF 6ES7521-1BL00-0AB0 | 35 x 147 x 129 | single source (TED) | | TED | |
| AI 8xU/I/RTD/TC ST 6ES7531-7KF00-0AB0 | 35 x 147 x 129 | single source (TED; Baldwin page 404) | LEDs as above; front connector, infeed element, shield bracket and shield terminal | TED | |
| AI 8xU/I HS 6ES7531-7NF10-0AB0 | 35 x 147 x 129 | single source (TED) | | TED | |
| DI 16x24VDC BA 6ES7521-1BH10-0AA0 (25 mm class) | 25 x 147 x 129 | confirmed (TED + Baldwin "147 H x 25 W x 129 D") | supplied with 40-pole push-in front connector; LEDs RUN green, ERROR red, channel green | TED; baldwinsupply.com/itemdetail/6ES75211BH100AA0 | |
| Mounting rail 6ES7590-1AE80-0AA0 (482.6 mm) | 482 x 155 x 16 (data sheet rounds; product name says "482.6 mm (approx. 19 inch)") | single source (TED) | aluminium, integrated DIN rail | TED | |
| ET 200SP DI 8x24VDC 6ES7131-6BF01-0AA0 | 15 x 73 x 58 | confirmed (TED + Baldwin "73 H x 15 W x 58 D") | PWR LED green, per-channel green, DIAG green/red, colour-coded label CC01 | TED; baldwinsupply.com/itemdetail/6ES71316BF010AA0 | |
| ET 200SP DQ 8x24VDC/0.5A 6ES7132-6BF01-0AA0 | 15 x 73 x 58 | single source (TED) | | TED | |
| ET 200SP AI 4xU/I 2-wire ST 6ES7134-6HD01-0BA1 | 15 x 73 x 58 | single source (TED) | | TED | |
| ET 200SP BaseUnit BU15-P16+A0+2B 6ES7193-6BP00-0BA0 | 15 x 117 x 35 | confirmed (TED text "WxH: 15x 117 mm" + depth 35; Baldwin "117 H x 15 W x 35 D") | 16 push-in terminals, colour code CC00..CC09 | TED; baldwinsupply.com/itemdetail/6ES71936BP000BA0 | |
| ET 200SP BaseUnit BU15-P16+A10+2B 6ES7193-6BP20-0BA0 (a 15 mm wide base with AUX terminals; not a 20 mm BU20) | 15 x 141 x 35 | confirmed (TED "WxH: 15 mm x 141 mm" + Baldwin 141 H x 15 W x 35 D) | 10 AUX terminals | same | |
| ET 200SP interface module IM 155-6 PN ST 6ES7155-6AU01-0BN0 | 50 x 117 x 74 | confirmed (TED + Baldwin "117 H x 50 W x 74 D") | LEDs RUN green / ERROR red / MAINT yellow / PWR green; 2-port with BusAdapter (BA 2xRJ45 / 2xFC / 2xM12) | TED; baldwinsupply.com/itemdetail/6ES71556AU010BN0 | |
| ET 200SP server module 6ES7193-6PA00-0AA0 | 7 x 117 x 36 | single source (TED; Baldwin has no dimensions) | | TED | |
| ET 200M IM 153-2 DP HF 6ES7153-2BA10-0XB0 (BA02 is discontinued, TED empty) | 40 x 125 x 117 | single source (TED). IM 153-2 HF 6ES7153-2BA82-0XB0 has the same 40 x 125 x 117 | | TED | |
| BU20-P12+A0+4B (real BU20 with width 20 mm) | | not found | | | |

## 3. Rockwell Allen-Bradley

Documents downloaded from literature.rockwellautomation.com (paths in w2 folder): TD006 chassis, IN621 chassis install, TD005 and IN619 power supplies, 5069-TD001 I/O, 5069-TD002 controllers, 1734-IN051 IB8, 1734-IN511 / IN013 bases, 1734-IN042 / IN590 AENT. Distributor NHP (nhp.com.au) datasheets used as the second source for the chassis.

| item | W x H x D mm (source order) | status | front features | source | Korea evidence |
|---|---|---|---|---|---|
| 1756-A7 chassis (7 slot) | 367.6 x 158 x 145 | confirmed (NHP datasheet "Width 367.6 Height 158 Depth 145" + Rockwell TD006 / IN621 drawing 36.76, 15.8, 14.5 cm) | horizontal mount only | https://www.nhp.com.au/public/assets/pim/Original/10030/1756A7-AU-ControlLogix-Chassis-Datasheet.pdf ; TD006 https://literature.rockwellautomation.com/idc/groups/literature/documents/td/1756-td006_-en-e.pdf ; IN621 | TD006 lists "KC Korean Registration of Broadcasting and Communications Equipment" |
| 1756-A13 chassis (13 slot) | 587.6 x 158 x 145 | confirmed (NHP + TD006 58.76 cm) | | NHP 1756A13 datasheet; TD006 | same |
| 1756-A4 chassis | 262.6 (from drawing pair 23.01 / 26.26 cm, larger value assumed) x 158 x 145 | NOT confirmed. Drawing text has only unlabeled numbers; 26.26 cm for A4, 48.26 cm for A10 and 73.76 cm for A17 are assumptions by pattern. Use with care | | TD006, IN621 | |
| 1756-A10 chassis | 482.6 (assumed from drawing 45.01 / 48.26 cm pair) x 158 x 145 | not confirmed (see above). Slot pitch pattern is inconsistent, 19-inch width plausible | | same | |
| 1756-A17 chassis | 737.6 (assumed from 70.54 / 73.76 cm pair) x 158 x 145 | not confirmed | | same | |
| 1756-PA72 / PA75 power supply (standard) | 112 x 140 x 145 (spec table states HxWxD 14.0 x 11.2 x 14.5 cm) | confirmed (TD005 and IN619, two Rockwell documents, column mapping to PA72 read from header) | | https://literature.rockwellautomation.com/idc/groups/literature/documents/td/1756-td005_-en-e.pdf ; 1756-in619 | |
| 1756-PA50 / PB50 (slim) | 78 x 140 x 145 (14.0 x 7.8 x 14.5 cm as HxWxD) | confirmed (TD005 + IN619) | | same | |
| 1756-PB72 (DC) | listed in the same block as PA72 | column mapping less certain, treat as single source | | TD005 | |
| 1756-L7x controller, 1756-IB16 / OB16 / IF16 modules | | NOT FOUND in Rockwell TD001 / TD002 / IN docs (no dimension lines). Search summary said IB16 38.1 W and L71 "5.08 x 18.16 x 23.24 cm" from unnamed pages; these were not verified and must not be used | | | |
| 5069-IB16, 5069-OB16 (1 slot) | 22 x 144.6 x 105.4 | single source (Rockwell 5069-TD001, "Dimensions (HxWxD) 144.6 x 22 x 105.4 mm"; the 32-pt and relay 5069-OW16 columns are 36 mm wide, mapping of two values to three column groups is uncertain) | needs 5069-RTB18-SPRING or SCREW terminal block, DIN rail 35 x 7.5, slot width 1 | https://literature.rockwellautomation.com/idc/groups/literature/documents/td/5069-td001_-en-p.pdf | 5069 datasheets list KC Korean Registration |
| 5069-L3xx CompactLogix 5380 (L306ER .. L3100ERM) | 98.10 x 143.97 x 136.81 | single source (5069-TD002, "HxWxD 143.97 x 98.10 x 136.81 mm") | 2 Ethernet ports, USB, SD card slot | https://literature.rockwellautomation.com/idc/groups/literature/documents/td/5069-td002_-en-p.pdf | same |
| 5069 Compact GuardLogix SIL 3 | 153.5 x 143.71 x 136.81 | single | | 5069-TD002 | |
| 5069-AENTR | 25 or 63 or 98.1 (three widths, mapping to catalog numbers not resolved), H 144.6 or 123.0, D 105.4 or 136.8 | not readable (table columns ambiguous) | | 5069-TD001 | |
| 1734-IB8 (module only, on 1734-TB base) | 12 x 56 x 75.5 | single source (1734-IN051, "HxWxD 56 x 12 x 75.5 mm"; another 1734 spec sheet lists the same for an IO-Link module) | indicators: 1 green/red network, 1 green/red module, 8 yellow input, on the logic side | http://www.elettronicalucense.it/Product/Datasheet/ALLEN-BRADLEY/AL-1734-IB8.pdf (copy of Rockwell IN051) | |
| 1734-TB / 1734-TBS wiring base | 12 x 65 x 133.4 | single source (1734-IN511 "HxWxD approx 65 x 12 x 133.4 mm") | 1734-TB3 / TB3S: 12 x 65 x 160 (1734-IN013) | Rockwell 1734-IN511, 1734-IN013 | |
| 1734-AENT | 54.9 x 76.2 x 133.4 (older IN590) and 56.1 x 75.3 x 133.1 (newer IN042J, series C) | two documents give slightly different values (revision). Drawing in IN042: 75.3 / 56.1 / 133.1, plus 52.23 and 35.55 (locating dims) | status indicators on top, RJ45, thumbwheel (pen push) switches, orange DIN rail locking screw | Rockwell 1734-IN590, 1734-IN042 | |
| 1769 Compact I/O | | not searched (optional) | | | |

## Not found list
- LS: XGI-D24A, XGQ-TR2A, XGF-AD8A individual sizes (only SOEA 27 x 98 x 90 and general "27 x 98 x 90 module"); XGT Remote (XGR/GPL); exact power-module dimensions per model; housing colour, latch, label slot.
- Siemens: BU20 real 20 mm base unit; PM 70W 120/230V AC (6EP1332-4BA00 is 24V/3A PM 1507); ET 200SP DI/DQ/AI more than one confirmed; S7-1500 25 mm module list other than DI BA; IM 153-2 second source.
- Rockwell: 1756-L7x controller, 1756-IB16/OB16/IF16 modules (widths), 1756-A4/A10/A17 exact widths, 1769.
- Second source for most LS items and the Siemens 1516/PS60/rail/server module/IM153 items.
