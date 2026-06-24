# -*- coding: utf-8 -*-
"""세끌 테스트용 '격자 폼' 샘플 PDF 생성기.

테두리·칸·섹션 밴드가 있는 표 형태의 정부 서식처럼 그리되,
각 행의 라벨과 값을 같은 baseline(같은 y)에 배치한다.
→ Syncfusion layoutText 추출 시 "라벨+값"이 한 줄로 붙어 앱 파서가 정확히 읽는다.
(정부 HWP를 그대로 렌더링하면 칸 병합 탓에 줄이 어긋나 파싱이 깨짐 — 그래서 이 방식 사용)

한글: 맑은고딕 TTF 임베드.
"""
import os
from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import A4
from reportlab.lib.colors import Color
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont

FONT = "Malgun"
pdfmetrics.registerFont(TTFont(FONT, r"C:\Windows\Fonts\malgun.ttf"))

OUT = r"C:\Users\vedja\OneDrive\Desktop\세끌_테스트_PDF"
os.makedirs(OUT, exist_ok=True)

W, H = A4
ML, MR, MT, MB = 36, 36, 40, 40           # margins
CONTENT_W = W - ML - MR
LINE = Color(0.45, 0.45, 0.45)
BAND = Color(0.90, 0.90, 0.90)
INK = Color(0.08, 0.08, 0.08)
FS = 8.4
RH = 16.0                                  # row height


def won(n):
    return f"{n:,}"


def split12(total):
    if total <= 0:
        return [0] * 12
    b = total // 12
    a = [b] * 12
    a[-1] += total - b * 12
    return a


class Form:
    """위→아래로 테두리 있는 행을 그린다. 모든 셀 텍스트는 행의 같은 baseline."""

    def __init__(self, fname, title):
        self.path = os.path.join(OUT, fname)
        self.c = canvas.Canvas(self.path, pagesize=A4)
        self.c.setLineWidth(0.5)
        self.c.setStrokeColor(LINE)
        self.y = H - MT
        self._title(title)

    def _newpage_if_needed(self, h):
        if self.y - h < MB:
            self.c.showPage()
            self.c.setLineWidth(0.5)
            self.c.setStrokeColor(LINE)
            self.y = H - MT

    def _title(self, text):
        self.c.setFont(FONT, 11)
        self.c.setFillColor(INK)
        self.c.drawString(ML, self.y - 11, text)
        self.y -= 22

    def band(self, text):
        """섹션 헤더 밴드(회색)."""
        h = RH
        self._newpage_if_needed(h)
        top = self.y
        self.c.setFillColor(BAND)
        self.c.rect(ML, top - h, CONTENT_W, h, stroke=1, fill=1)
        self.c.setFillColor(INK)
        self.c.setFont(FONT, FS + 0.6)
        self.c.drawString(ML + 5, top - h + 4.5, text)
        self.y -= h

    def row(self, cells):
        """cells: [(text, width_fraction, align)] — align: 'l'/'r'/'c'.
        한 행의 모든 셀 텍스트가 같은 baseline → 추출 시 한 줄."""
        h = RH
        self._newpage_if_needed(h)
        top = self.y
        x = ML
        self.c.setFont(FONT, FS)
        self.c.setFillColor(INK)
        baseline = top - h + 4.5
        for text, frac, align in cells:
            w = CONTENT_W * frac
            self.c.rect(x, top - h, w, h, stroke=1, fill=0)
            if text:
                if align == 'r':
                    self.c.drawRightString(x + w - 5, baseline, text)
                elif align == 'c':
                    self.c.drawCentredString(x + w / 2, baseline, text)
                else:
                    self.c.drawString(x + 5, baseline, text)
            x += w
        self.y -= h

    def kv(self, label, value, lf=0.58):
        """라벨 | 값(우측정렬) — 같은 행/같은 baseline."""
        self.row([(label, lf, 'l'), (value, 1 - lf, 'r')])

    def note(self, text):
        """전폭 작은 안내문(테두리 없음)."""
        h = 12
        self._newpage_if_needed(h)
        self.c.setFont(FONT, FS - 1.2)
        self.c.setFillColor(Color(0.35, 0.35, 0.35))
        self.c.drawString(ML, self.y - h + 3, text)
        self.y -= h
        self.c.setFillColor(INK)

    def gap(self, h=6):
        self.y -= h

    def save(self):
        self.c.showPage()
        self.c.save()
        return self.path


# ════════════════════════════════════════════════════════════════
# 1) 사업소득 원천징수영수증 [별지23(3)]
# ════════════════════════════════════════════════════════════════
def make_freelancer(fname, d, name="홍프리"):
    inc = d['income']
    f = Form(fname, "■ 소득세법 시행규칙 [별지 제23호서식(3)]  사업소득 원천징수영수증(연말정산용)")
    f.row([("[ √ ] 소득자 보관용", 0.5, 'l'), ("귀속연도   2025년", 0.5, 'l')])
    f.band("징수의무자")
    f.row([("② 법인명(상호)", 0.3, 'l'), ("(주)세끌플랫폼", 0.35, 'l'), ("③ 사업자등록번호", 0.2, 'l'), ("126-81-44920", 0.15, 'l')])
    f.band("소득자")
    f.row([("⑩ 성명", 0.2, 'l'), (name, 0.3, 'l'), ("⑪ 주민등록번호", 0.25, 'l'), ("000000-*******", 0.25, 'l')])
    f.band("수입금액")
    f.row([("⑬ 발생처 구분", 0.3, 'l'), ("주(현)  사업소득", 0.4, 'l'), ("발생기간", 0.3, 'l')])
    f.kv("보험모집 수입금액 계", "0")
    f.kv("방문판매 수입금액 계", "0")
    f.kv("합 계 (124)", won(d['gross']))
    f.band("소득금액")
    f.row([("사 업 별", 0.3, 'l'), ("수입금액", 0.25, 'r'), ("적용소득률", 0.2, 'r'), ("소득금액", 0.25, 'r')])
    f.row([("합계", 0.3, 'l'), (won(d['gross']), 0.25, 'r'),
           (f"{round(inc/d['gross']*100,1) if d['gross'] else 0}%", 0.2, 'r'), (won(inc), 0.25, 'r')])
    f.kv("수입금액", won(d['gross']))
    f.kv("소득금액", won(inc))
    f.band("세액의 계산")
    f.row([("구분", 0.34, 'l'), ("소득세", 0.22, 'r'), ("지방소득세", 0.22, 'r'), ("농어촌특별세", 0.22, 'r')])
    f.kv("종합소득과세표준", won(max(inc - 1500000, 0)))
    f.kv("산출세액", won(d['decided']))
    f.kv("인적공제 본인", "1,500,000")
    f.kv("결정세액", won(d['decided']))
    f.kv("종(전) 근무지", "0")
    f.kv("기납부세액 (원천징수 3.3%)", won(d['decided'] - d['final']))
    f.kv("차감 납부할 세액", won(d['final']))
    f.gap()
    f.note("※ 차감 납부할 세액이 음수이면 환급입니다. 위 원천징수세액(수입금액)을 정히 영수(지급)합니다.")
    f.note("210mm×297mm(백상지 80g/㎡)")
    return f.save()


# ════════════════════════════════════════════════════════════════
# 2) 근로소득 원천징수영수증 [별지24]
# ════════════════════════════════════════════════════════════════
def make_wonchun(fname, g, name="김근로"):
    f = Form(fname, "■ 소득세법 시행규칙 [별지 제24호서식(1)]  근로소득 원천징수영수증")
    f.row([("[ √ ] 소득자 보관용", 0.5, 'l'), ("연말정산구분  계속근로", 0.5, 'l')])
    f.band("징수의무자")
    f.row([("① 법인명(상호)", 0.3, 'l'), ("(주)세끌컴퍼니", 0.35, 'l'), ("③ 사업자등록번호", 0.2, 'l'), ("126-81-44920", 0.15, 'l')])
    f.band("소득자")
    f.row([("⑥ 성명", 0.2, 'l'), (name, 0.3, 'l'), ("⑦ 주민등록번호", 0.25, 'l'), ("000000-*******", 0.25, 'l')])
    f.band("Ⅰ. 근무처별 소득명세")
    f.row([("구분", 0.4, 'l'), ("주(현)", 0.3, 'r'), ("합계", 0.3, 'r')])
    f.row([("⑬ 급여", 0.4, 'l'), (won(g['gross']), 0.3, 'r'), (won(g['gross']), 0.3, 'r')])
    f.kv("16 계", won(g['gross']))
    f.band("Ⅲ. 세액명세")
    f.row([("구분", 0.34, 'l'), ("소득세", 0.22, 'r'), ("지방소득세", 0.22, 'r'), ("농어촌특별세", 0.22, 'r')])
    f.row([("73 결정세액", 0.34, 'l'), (won(g['decided']), 0.22, 'r'), (won(round(g['decided'] * 0.1)), 0.22, 'r'), ("0", 0.22, 'r')])
    f.row([("75 주(현)근무지", 0.34, 'l'), (won(g['paid']), 0.22, 'r'), (won(round(g['paid'] * 0.1)), 0.22, 'r'), ("0", 0.22, 'r')])
    f.row([("77 차감징수세액", 0.34, 'l'), (won(g['final']), 0.22, 'r'), (won(round(g['final'] * 0.1)), 0.22, 'r'), ("0", 0.22, 'r')])
    f.band("Ⅳ. 정산명세")
    f.kv("21 총급여", won(g['gross']))
    f.kv("22 근로소득공제", won(g['laborDed']))
    f.kv("23 근로소득금액", won(g['gross'] - g['laborDed']))
    f.kv("48 종합소득과세표준", won(g['taxableBase']))
    f.kv("49 산출세액", won(g['calcTax']))
    f.band("종합소득공제 / 세액공제 명세")
    f.row([("31 국민연금보험료", 0.5, 'l'), ("대상금액", 0.25, 'l'), (won(g['np']), 0.25, 'r')])
    f.row([("33㉮ 건강보험료", 0.5, 'l'), ("대상금액", 0.25, 'l'), (won(g['health']), 0.25, 'r')])
    f.row([("33㉯ 고용보험료", 0.5, 'l'), ("대상금액", 0.25, 'l'), (won(g['emp']), 0.25, 'r')])
    # 신고된 공제대상금액(라벨 행 + 다음 행 '공제대상금액 N' — 파서 _claimedNear 호환)
    for code, lab, key in [("60", "연금저축", 'c_pension'), ("61", "보장성", 'c_life'),
                           ("62", "의료비", 'c_medical'), ("63", "교육비", 'c_education'),
                           ("64", "기부금", 'c_donation'), ("70", "월세액", 'c_rent')]:
        f.row([(f"{code} {lab}", 0.4, 'l'), ("공제대상금액", 0.35, 'l'), (won(g[key]), 0.25, 'r')])
    f.kv("72 결정세액 (49-54-71)", won(g['decided']))
    f.gap()
    f.note("※ 77 차감징수세액이 음수이면 환급입니다.  210mm×297mm(백상지 80g/㎡)")
    return f.save()


# ════════════════════════════════════════════════════════════════
# 3) 연금소득 원천징수영수증 [별지24(5)]
# ════════════════════════════════════════════════════════════════
def make_pension(fname, d, name="박연금"):
    gross = d['gross']
    ded = d['ded']
    inc = gross - ded
    final = d['decided'] - d['paid']
    f = Form(fname, "■ 소득세법 시행규칙 [별지 제24호서식(5)]  연금소득 원천징수영수증(연말정산용)")
    f.row([("[ √ ] 소득자 보관용", 0.5, 'l'), ("귀속연도  2025년", 0.5, 'l')])
    f.band("징수의무자")
    f.row([("① 법인명", 0.3, 'l'), ("국민연금공단", 0.35, 'l'), ("③ 사업자등록번호", 0.2, 'l'), ("116-82-00001", 0.15, 'l')])
    f.band("소득자")
    f.row([("⑥ 성명", 0.2, 'l'), (name, 0.3, 'l'), ("⑦ 주민등록번호", 0.25, 'l'), ("000000-*******", 0.25, 'l')])
    f.band("연금 지급 내역")
    f.kv("⑪ 총연금수령액", won(gross))
    f.kv("⑫ 연금제외소득 (2001.12.31 이전분)", "0")
    f.kv("⑬ 장애연금등 비과세연금", "0")
    f.kv("⑭ 총연금액 (⑪-⑫-⑬)", won(gross))
    f.band("정산명세")
    f.kv("⑮ 총연금액 (=⑭)", won(gross))
    f.kv("⑯ 연금소득공제", won(ded))
    f.kv("⑰ 연금소득금액 (⑮-⑯)", won(inc))
    f.kv("종합소득과세표준", won(max(inc - 1500000, 0)))
    f.kv("산출세액", won(d['decided']))
    f.kv("기본공제 본인", "1,500,000")
    f.band("세액명세")
    f.row([("구분", 0.34, 'l'), ("소득세", 0.22, 'r'), ("지방소득세", 0.22, 'r'), ("농어촌특별세", 0.22, 'r')])
    f.row([("결정세액", 0.34, 'l'), (won(d['decided']), 0.22, 'r'), (won(round(d['decided'] * 0.1)), 0.22, 'r'), ("0", 0.22, 'r')])
    f.row([("기납부세액", 0.34, 'l'), (won(d['paid']), 0.22, 'r'), (won(round(d['paid'] * 0.1)), 0.22, 'r'), ("0", 0.22, 'r')])
    f.row([("차감징수세액", 0.34, 'l'), (won(final), 0.22, 'r'), (won(round(final * 0.1)), 0.22, 'r'), ("0", 0.22, 'r')])
    f.gap()
    f.note("※ 차감징수세액이 음수이면 환급입니다.  210mm×297mm[백상지 80g/㎡]")
    return f.save()


# ════════════════════════════════════════════════════════════════
# 4) 연말정산 간소화 자료
# ════════════════════════════════════════════════════════════════
def make_ganso(fname, d, name="홍길동"):
    f = Form(fname, "2025년 귀속 소득·세액공제 증명서류 (연말정산 간소화 자료)")
    f.note("(조회기간 : 2025년 01 ~ 12월)   성명 " + name + "  주민등록번호 000000-*******")

    # 건강보험료
    f.band("[건강보험료]")
    f.row([("월별", 0.34, 'l'), ("건강보험료", 0.33, 'r'), ("장기요양보험료", 0.33, 'r')])
    g_tot = round(d['health'] * 0.872)
    y_tot = d['health'] - g_tot
    gm, ym = split12(g_tot), split12(y_tot)
    for i in (0, 5, 11):
        f.row([(f"{i+1:02d}월", 0.34, 'l'), (won(gm[i]), 0.33, 'r'), (won(ym[i]), 0.33, 'r')])
    f.row([("합계", 0.34, 'l'), (won(g_tot), 0.33, 'r'), (won(y_tot), 0.33, 'r')])
    f.kv("총합계", won(d['health']))

    # 고용보험료
    f.band("[고용보험료]")
    f.kv("합계", won(d['emp']))

    # 국민연금보험료
    f.band("[국민연금보험료]")
    f.kv("합계", won(d['np']))
    f.kv("총합계", won(d['np']))

    # 보장성보험
    f.band("[보장성 보험, 장애인전용보장성보험]")
    if d['life'] > 0:
        f.row([("메리츠화재(무)건강보험", 0.6, 'l'), ("납입금액 계", 0.2, 'l'), (won(d['life']), 0.2, 'r')])
    f.kv("인별합계금액", won(d['life']))

    # 실손의료보험금
    f.band("[실손의료보험금]")
    f.kv("인별합계금액", won(d['reimb']))

    # 의료비
    f.band("[의료비]")
    f.row([("사업자번호", 0.34, 'l'), ("종류", 0.33, 'l'), ("지출금액 계", 0.33, 'r')])
    if d['med'] > 0:
        f.row([("**6-90-68***", 0.34, 'l'), ("일반", 0.33, 'l'), (won(d['med'] - d.get('inf', 0)), 0.33, 'r')])
        if d.get('inf', 0) > 0:
            f.row([("난임시술병원", 0.34, 'l'), ("난임 인별합계금액", 0.33, 'l'), (won(d['inf']), 0.33, 'r')])
        f.kv("의료비 인별합계금액", won(d['med']))
    f.kv("인별합계금액", won(d['med']))

    # 신용카드
    f.band("[신용카드]")
    f.row([("일반", 0.25, 'r'), ("전통시장", 0.25, 'r'), ("대중교통", 0.25, 'r'), ("합계금액", 0.25, 'r')])
    f.row([(won(d['credit']), 0.25, 'r'), ("0", 0.25, 'r'), ("0", 0.25, 'r'), (won(d['credit']), 0.25, 'r')])
    f.kv("인별합계금액", won(d['credit']))

    # 직불카드
    f.band("[직불카드 등]")
    f.kv("인별합계금액", won(d['debit']))

    # 현금영수증
    f.band("[현금영수증]")
    f.row([("일반", 0.2, 'r'), ("전통시장", 0.2, 'r'), ("대중교통", 0.2, 'r'), ("주택임차료", 0.2, 'r'), ("합계금액", 0.2, 'r')])
    f.row([(won(d['cash']), 0.2, 'r'), ("0", 0.2, 'r'), ("0", 0.2, 'r'), ("0", 0.2, 'r'), (won(d['cash']), 0.2, 'r')])
    f.kv("인별합계금액", won(d['cash']))

    if d.get('edu', 0) > 0:
        f.band("[교육비]")
        f.row([("○○대학교", 0.5, 'l'), ("대학 납입금액 계", 0.3, 'l'), (won(d['edu']), 0.2, 'r')])
        f.kv("인별합계금액", won(d['edu']))
    if d.get('don', 0) > 0:
        f.band("[기부금]")
        f.row([("○○재단", 0.5, 'l'), ("지정기부금", 0.3, 'l'), (won(d['don']), 0.2, 'r')])
        f.kv("인별합계금액", won(d['don']))
    if d.get('pension', 0) > 0:
        f.band("[연금저축]")
        f.row([("○○증권 123-456", 0.55, 'l'), ("납입금액 계", 0.2, 'l'), (won(d['pension']), 0.25, 'r')])
    if d.get('rent', 0) > 0:
        f.band("[월세액]")
        f.row([("김임대", 0.5, 'l'), ("주택", 0.3, 'l'), (won(d['rent']), 0.2, 'r')])
        f.kv("인별합계금액", won(d['rent']))

    f.gap()
    f.note("※ 본 증명서류는 『소득세법』 제165조 제1항에 따라 수집된 서류입니다.")
    return f.save()


# ───────────────────────── 데이터(기존 시나리오 동일) ─────────────────────────
GANSO = {
    "간소화_01_종합세트.pdf": dict(health=1782490, emp=389280, np=1686420, life=2968840, reimb=71000, med=3500000, inf=1200000, credit=12000000, debit=4000000, cash=2724031, edu=5000000, don=1500000, pension=6000000, rent=7500000),
    "간소화_02_의료비집중.pdf": dict(health=1500000, emp=300000, np=1400000, life=800000, reimb=500000, med=8000000, inf=3000000, credit=5000000, debit=1000000, cash=500000),
    "간소화_03_카드집중.pdf": dict(health=1600000, emp=350000, np=1500000, life=0, reimb=0, med=0, inf=0, credit=25000000, debit=8000000, cash=3000000),
    "간소화_04_연금월세교육.pdf": dict(health=1200000, emp=250000, np=1100000, life=1000000, reimb=0, med=600000, inf=0, credit=6000000, debit=2000000, cash=1000000, edu=8000000, don=2000000, pension=9000000, rent=9000000),
    "간소화_05_최소.pdf": dict(health=900000, emp=180000, np=800000, life=0, reimb=0, med=0, inf=0, credit=2000000, debit=0, cash=0),
}
WONCHUN = {
    "근로소득_01_환급_저신고.pdf": dict(gross=33295138, laborDed=10244270, taxableBase=17486345, calcTax=1362951, paid=806640, decided=509066, final=-297570, np=1686420, health=1782490, emp=299610, c_medical=0, c_education=0, c_rent=0, c_life=1000000, c_pension=0, c_donation=0),
    "근로소득_02_납부.pdf": dict(gross=55000000, laborDed=12750000, taxableBase=32000000, calcTax=3900000, paid=2800000, decided=3200000, final=400000, np=2475000, health=2100000, emp=440000, c_medical=500000, c_education=1000000, c_rent=0, c_life=1000000, c_pension=2000000, c_donation=100000),
    "근로소득_03_고소득.pdf": dict(gross=95000000, laborDed=14750000, taxableBase=62000000, calcTax=11000000, paid=12500000, decided=10200000, final=-2300000, np=2700000, health=3500000, emp=760000, c_medical=3000000, c_education=5000000, c_rent=0, c_life=1000000, c_pension=6000000, c_donation=1500000),
    "근로소득_04_중간_부분신고.pdf": dict(gross=42000000, laborDed=11550000, taxableBase=24000000, calcTax=2520000, paid=2000000, decided=2100000, final=100000, np=1890000, health=1700000, emp=336000, c_medical=200000, c_education=0, c_rent=3000000, c_life=500000, c_pension=0, c_donation=0),
    "근로소득_05_저소득_환급.pdf": dict(gross=26000000, laborDed=9090000, taxableBase=13000000, calcTax=858000, paid=600000, decided=300000, final=-300000, np=1170000, health=1100000, emp=208000, c_medical=0, c_education=0, c_rent=0, c_life=0, c_pension=0, c_donation=0),
}
FREELANCER = {
    "사업소득_01_환급.pdf": dict(gross=30000000, income=12000000, decided=600000, final=-390000),
    "사업소득_02_납부.pdf": dict(gross=60000000, income=30000000, decided=3400000, final=1420000),
    "사업소득_03_고소득_납부.pdf": dict(gross=120000000, income=70000000, decided=13500000, final=9540000),
    "사업소득_04_저소득_환급.pdf": dict(gross=15000000, income=6000000, decided=200000, final=-295000),
    "사업소득_05_중간_납부.pdf": dict(gross=45000000, income=22000000, decided=1900000, final=415000),
}
PENSION = {
    "연금소득_01_국민연금_환급.pdf": dict(gross=6000000, ded=4100000, decided=100000, paid=150000),
    "연금소득_02_직역연금_납부.pdf": dict(gross=24000000, ded=6300000, decided=1500000, paid=1300000),
    "연금소득_03_중간_환급.pdf": dict(gross=13200000, ded=5460000, decided=500000, paid=560000),
    "연금소득_04_고액_납부.pdf": dict(gross=40000000, ded=9000000, decided=3200000, paid=2900000),
    "연금소득_05_저액_환급.pdf": dict(gross=9000000, ded=4650000, decided=200000, paid=250000),
}


def main():
    made = []
    for fn, d in GANSO.items():
        made.append(make_ganso(fn, d))
    for fn, d in WONCHUN.items():
        made.append(make_wonchun(fn, d))
    for fn, d in FREELANCER.items():
        made.append(make_freelancer(fn, d))
    for fn, d in PENSION.items():
        made.append(make_pension(fn, d))
    print(f"TOTAL {len(made)} form PDFs -> {OUT}")


if __name__ == "__main__":
    main()
