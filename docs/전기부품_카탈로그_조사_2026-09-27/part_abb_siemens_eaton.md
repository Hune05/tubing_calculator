# ABB / Siemens / Eaton front-view dimensions (mm) - research 2026-09-27

Rule: CONFIRMED = two different sources agree; SINGLE SOURCE = one; UNREAD = not readable.
H = height (DIN-rail vertical), W = width (front), D = depth from mounting surface.
Front features (coil terminal position, colour, dial layout) were NOT readable from any datasheet text; all "features" columns are UNREAD unless stated.

Tool limits hit: WebSearch budget (200) exhausted mid-task; new.abb.com, eaton.com, datasheet.eaton.com (JS/selector page), RS, TME, Farnell, alldatasheet, Siemens mall all timed out / 403 / selector-only. No search-engine scraping workaround used.

## Siemens SIRIUS (source: Siemens TED datasheet PDFs, apim.industry.siemens.cloud/ted/datasheet?format=pdf&mlfbs=<MLFB>, generated 26 Sep 2026, section "Installation/mounting/dimensions", read with pdftotext)

| Item | Frame / poles | W | H | D | Status | Notes |
|---|---|---|---|---|---|---|
| 3RT2015-1BB41 | S00, 3P, 24VDC coil | 45 | 58 | 73 | CONFIRMED (Siemens TED PDF + ideadigitalcontent.com copy of Siemens datasheet - same origin, weak independence) | DIN 35 snap-on, side-by-side 0 mm gap |
| 3RT2016-1BB41 | S00 | 45 | 58 | 73 | SINGLE SOURCE (TED) | |
| 3RT2018-1BB41 | S00 | 45 | 58 | 73 | SINGLE SOURCE (TED) | |
| 3RT2024-1BB40 | S0 | 45 | 85 | 107 | SINGLE SOURCE (TED) | |
| 3RT2026-1BB40 | S0 | 45 | 85 | 107 | SINGLE SOURCE (TED) | |
| 3RT2027-1BB40 | S0 | 45 | 85 | 107 | SINGLE SOURCE (TED) | |
| 3RT2028-1BB40 | S0 | 45 | 85 | 107 | SINGLE SOURCE (TED) | |
| 3RU2116-1HB0 | S00 thermal OL, Class 10 | 45 | 76 | 70 | SINGLE SOURCE (TED) | Manual/Auto reset, "tripped" aux |
| 3RU2126-1JB0 | S0 thermal OL | 45 | 85 | 85 | SINGLE SOURCE (TED) | |
| 3RB3016-1RB0 | S00 electronic OL, Class 10E | 45 | 79 | 73 | SINGLE SOURCE (TED) | Manual-Automatic-Remote RESET |
| 3RB3026-1QB0 | S0 electronic OL | 45 | 87 | 84 | SINGLE SOURCE (TED) | |
| 3RP2005-1BW30 | 3RP20 timer, 16 functions, 24-240 V AC/DC | 45 | 57 | 73 | SINGLE SOURCE (TED; title says "overall width 45 mm" = self-consistent) | |
| 3RP2505-1BW30 | 3RP25 timer, 27 functions, 22.5 mm | 22.5 | 100 | 90 | SINGLE SOURCE (TED) | LED |
| 3RP1505-1BW30 | 3RP15 timer (phased-out) | 22.5 | 102 | 91 | SINGLE SOURCE (TED) | LED |
| 7PV timer | - | UNREAD | | | UNREAD | 7PV1577-1AW30 returned 404 |

Note: heights above are bare device; stacked overload relay adds to depth-below (H) - 3RU/3RB heights are the relay alone, contactor+relay stack height = contactor H + relay H approx. (not verified).

## ABB

| Item | Frame | W | H | D | Status | Source |
|---|---|---|---|---|---|---|
| AF09-30-10-11 / -13 | AF09, 3P | 45 | 86 | 77 | CONFIRMED (standardelectricsupply.com AF09-30-10-11 + houseofelectrical.com AF09-30-10-13 - both US resellers, likely same feed, weak independence) | |
| AF12-30-10-13 | AF12 | 45 | 86 | 77 | SINGLE SOURCE (standardelectricsupply.com) | |
| AF16-30-10-11 | AF16 | 45 | 86 | 77 | SINGLE SOURCE (standardelectricsupply.com) | |
| AF26-30-00-11 | AF26 | 45 | 86 | 86 | SINGLE SOURCE (standardelectricsupply.com) | |
| AF38-30-00-13 / -11 | AF38 | 45 (1.77 in) | 86 (3.39 in) | 80 (3.15 in) | SINGLE SOURCE, AMBIGUOUS: listing gives 1.77 x 3.39 x 3.15 in, one page labels 3.39 as H and 3.15 as D, the other labels 3.39 as D and 3.15 as H | standardelectricsupply.com |
| AF30 | | UNREAD | | | UNREAD | page 404 |
| TF42-1.0 | thermal OL | 45 (1.77 in) | 88.4 (3.48 in) | 70.6 (2.78 in) | SINGLE SOURCE (inch-to-mm converted by me) | standardelectricsupply.com/ABB-TF42-1-0-Thermal-Overload-Relay |
| TF65 | | UNREAD | | | UNREAD | |
| CT-ERD / CT-MFD / CT-AHD | timers | UNREAD | | | UNREAD | new.abb.com timed out |
| CM-MPS / CM-PVS / CM-EFS | monitoring | UNREAD | | | UNREAD | |

## Eaton

| Item | W | H | D | Status | Source |
|---|---|---|---|---|---|
| DILM7...DILM15 (3P) | 45 | 68 | 75 | CONFIRMED (Eaton "Contactors" catalog dimension drawing, eaton.com.cn, page 142, scrambled text: 45/68/75 for "DILM7...DILM15"; + datasheet.eaton.com DILM9-10 via search summary only, not read directly) | catalog: fsw.uk.com/wp-content/uploads/2023/12/eaton_contactors_download_6.pdf (7.9 MB) |
| DILM17...DILM38 (3P) | 45 | 85 | 97.4 | CONFIRMED-ish (same catalog drawing: 45/85/97.4, and a search summary of Eaton DILM25-10 datasheet "45 x 85 x 97.4") | same |
| DILM17-DILM32 with top aux block (XHI) | 45 | 85 | up to 138 | SINGLE SOURCE (catalog drawing "138"; RS listing summary also 138) | same; treat as body depth 97.4 + aux |
| DILM12-10 | 45 | 68 | 125.2? | UNREAD/contradicts catalog (RS Japan summary, not read) - do not use | |
| ZB12 / ZB32 (ZB32-32) | 45 | 67? | 96? | UNREAD (search summary only: 45x67x96; page fetches all timed out; not verified) | eaton IL03407015Z pdf not readable |
| Catalog drawing hints for DILM7-15: mounting holes 2xM4, 35 mm DIN, side clearance to grounded parts 6 mm | | | | | |

## Korea usage evidence
UNREAD for all three: the fetch of Siemens Korea page loaded but names no SIRIUS product; ABB Korea and Eaton Korea pages timed out; no Korean distributor page fetched. (From general knowledge, all three brands are sold in Korea, but no source read.)

## Not found list
ABB: AF30 dims; TF65; CT-ERD, CT-MFD, CT-AHD; CM-MPS, CM-PVS, CM-EFS; any front-feature info; ABB catalog PDF.
Siemens: 7PV timer datasheet; front features (all).
Eaton: ZB12 / ZB32 dimensions (verified); DILM7/9/12/15/17/25/32 individual datasheet pages; front features.
Korea evidence: all.
