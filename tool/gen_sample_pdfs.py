# -*- coding: utf-8 -*-
"""세끌 테스트용 샘플 PDF 생성기.
실제 홈택스 추출 텍스트 포맷(test/fixtures 기준)을 미러링하여,
앱의 Syncfusion layoutText 추출 + 파서가 그대로 읽을 수 있는 PDF를 만든다.
한글은 맑은고딕 TTF를 임베드(ToUnicode 포함)하여 추출 정확도를 보장한다.
"""
import os
from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import A4
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont

FONT = "Malgun"
pdfmetrics.registerFont(TTFont(FONT, r"C:\Windows\Fonts\malgun.ttf"))

OUT = r"C:\src\project\sekkeul\sample_pdfs"
os.makedirs(OUT, exist_ok=True)

W, H = A4
MARGIN_X = 40
TOP = H - 50
LH = 13.5  # line height
FS = 9     # font size


def won(n):
    return f"{n:,}"


def render(filename, lines):
    """lines: list[str]; 한 줄당 drawString 한 번(레이아웃 추출 시 한 줄로 복원)."""
    path = os.path.join(OUT, filename)
    c = canvas.Canvas(path, pagesize=A4)
    c.setFont(FONT, FS)
    y = TOP
    for ln in lines:
        if y < 50:
            c.showPage()
            c.setFont(FONT, FS)
            y = TOP
        c.drawString(MARGIN_X, y, ln)
        y -= LH
    c.showPage()
    c.save()
    return path


# ─────────────────────────────────────────────────────────────
# 1) 연말정산 간소화 자료 (parseSimplifiedText)
# ─────────────────────────────────────────────────────────────
def ganso_lines(d):
    L = []

    def hdr(cat):
        L.append(f"2025년 귀속 소득 · 세액공제증명서류 : 기본내역 [{cat}]")
        L.append("(조회기간 : 2025년 01 ~ 12월)")
        L.append("성 명주 민 등 록 번 호")
        L.append("홍길동000000-*******")
        L.append("(단위:원)")

    hdr("건강보험료")
    L.append(f"합계{won(d['health'])}0")
    L.append(f"총합계{won(d['health'])}")

    hdr("고용보험료")
    L.append(f"합계{won(d['emp'])}")

    hdr("국민연금보험료")
    L.append(f"합계{won(d['np'])}0")
    L.append(f"총합계{won(d['np'])}")

    hdr("보장성 보험, 장애인전용보장성보험")
    L.append("종류상 호보험종류납입금액 계")
    L.append(f"보장성메리츠화재해상보험(무)건강보험{won(d['life'])}")
    L.append(f"인별합계금액{won(d['life'])}")

    hdr("실손의료보험금")
    L.append("상호상품명수령금액 계")
    L.append(f"우정사업본부(무)실손종합{won(d['reimb'])}")
    L.append(f"인별합계금액{won(d['reimb'])}")

    hdr("의료비")
    L.append("사 업 자 번 호상 호종 류지출금액 계")
    L.append(f"**6-90-68***조*****일반{won(d['med'])}")
    if d.get('inf', 0) > 0:
        L.append(f"난임시술비 종합병원 난임 인별합계금액{won(d['inf'])}")
    L.append(f"의료비 인별합계금액{won(d['med'])}")
    L.append(f"인별합계금액{won(d['med'])}")

    hdr("신용카드")
    L.append("구분사 업 자 번 호상 호종 류공제대상금액합계")
    L.append(f"신용카드202-81-48079신한카드일반{won(d['credit'])}")
    L.append(f"인별합계금액{won(d['credit'])}")

    hdr("직불카드 등")
    L.append("구분사 업 자 번 호상 호종 류공제대상금액합계")
    L.append(f"직불카드 등462-86-01671토스뱅크일반{won(d['debit'])}")
    L.append(f"인별합계금액{won(d['debit'])}")

    hdr("현금영수증")
    L.append("일반전통시장대중교통문화체육주택임차료합계금액")
    L.append(f"{won(d['cash'])}0000{won(d['cash'])}")
    L.append(f"인별합계금액{won(d['cash'])}")

    if d.get('edu', 0) > 0:
        hdr("교육비")
        L.append("상 호종 류납입금액 계")
        L.append(f"○○대학교대학{won(d['edu'])}")
        L.append(f"인별합계금액{won(d['edu'])}")

    if d.get('don', 0) > 0:
        hdr("기부금")
        L.append("기부유형기부처납입금액")
        L.append(f"지정기부금○○재단{won(d['don'])}")
        L.append(f"인별합계금액{won(d['don'])}")

    if d.get('pension', 0) > 0:
        hdr("연금저축")
        L.append("상 호계좌번호납입금액")
        L.append(f"○○증권123-456납입금액 계{won(d['pension'])}")

    if d.get('rent', 0) > 0:
        hdr("월세액")
        L.append("임대인유형납입금액")
        L.append(f"김임대주택{won(d['rent'])}")
        L.append(f"인별합계금액{won(d['rent'])}")

    return L


GANSO = {
    "간소화_01_종합세트.pdf": dict(health=1782490, emp=389280, np=1686420, life=2968840,
                              reimb=71000, med=3500000, inf=1200000, credit=12000000,
                              debit=4000000, cash=2724031, edu=5000000, don=1500000,
                              pension=6000000, rent=7500000),
    "간소화_02_의료비집중.pdf": dict(health=1500000, emp=300000, np=1400000, life=800000,
                               reimb=500000, med=8000000, inf=3000000, credit=5000000,
                               debit=1000000, cash=500000),
    "간소화_03_카드집중.pdf": dict(health=1600000, emp=350000, np=1500000, life=0,
                              reimb=0, med=0, inf=0, credit=25000000,
                              debit=8000000, cash=3000000),
    "간소화_04_연금월세교육.pdf": dict(health=1200000, emp=250000, np=1100000, life=1000000,
                                reimb=0, med=600000, inf=0, credit=6000000,
                                debit=2000000, cash=1000000, edu=8000000, don=2000000,
                                pension=9000000, rent=9000000),
    "간소화_05_최소.pdf": dict(health=900000, emp=180000, np=800000, life=0, reimb=0,
                           med=0, inf=0, credit=2000000, debit=0, cash=0),
}


# ─────────────────────────────────────────────────────────────
# 2) 근로소득 원천징수영수증 [별지24] (parseWithholdingText)
# ─────────────────────────────────────────────────────────────
def wonchun_lines(d):
    L = [
        "■소득세법시행규칙[별지제24호서식(1)](3쪽중제1쪽)",
        "[]근로소득원천징수영수증",
        "소득자",
        "⑥성명김***⑦주민등록번호(외국인등록번호)000000-*******",
        "구분주(현)종(전)16-1납세조합합계",
        f"⑬급여{won(d['gross'])}{won(d['gross'])}",
        f"16계{won(d['gross'])}{won(d['gross'])}",
        "Ⅲ세액명세",
        "구분79소득세80지방소득세81농어촌특별세",
        f"73결정세액{won(d['decided'])}{won(round(d['decided']*0.1))}0",
        "기납부세액",
        f"75주(현)근무지{won(d['paid'])}{won(round(d['paid']*0.1))}0",
        f"77차감징수세액(73-74-75-76){won(d['final'])}{won(round(d['final']*0.1))}0",
        "Ⅳ정산명세",
        f"21총급여{won(d['gross'])}",
        f"22근로소득공제{won(d['laborDed'])}",
        f"23근로소득금액{won(d['gross']-d['laborDed'])}",
        f"48종합소득과세표준{won(d['taxableBase'])}",
        f"49산출세액{won(d['calcTax'])}",
        "세액공제",
        "연금계좌",
        "60연금저축",
        f"공제대상금액{won(d['c_pension'])}",
        "세액공제액0",
        "특별세액공제",
        "61보험료",
        "보장성",
        f"공제대상금액{won(d['c_life'])}",
        "세액공제액0",
        "62의료비",
        f"공제대상금액{won(d['c_medical'])}",
        "세액공제액0",
        "63교육비",
        f"공제대상금액{won(d['c_education'])}",
        "세액공제액0",
        "64기부금",
        "㉮정치자금기부금10만원이하",
        f"공제대상금액{won(d['c_donation'])}",
        "세액공제액0",
        "70월세액",
        f"공제대상금액{won(d['c_rent'])}",
        "세액공제액0",
        f"72결정세액(49-54-71){won(d['decided'])}",
    ]
    return L


WONCHUN = {
    "근로소득_01_환급_저신고.pdf": dict(gross=33295138, laborDed=10244270, taxableBase=17486345,
                                  calcTax=1362951, paid=806640, decided=509066, final=-297570,
                                  c_medical=0, c_education=0, c_rent=0, c_life=1000000,
                                  c_pension=0, c_donation=0),
    "근로소득_02_납부.pdf": dict(gross=55000000, laborDed=12750000, taxableBase=32000000,
                             calcTax=3900000, paid=2800000, decided=3200000, final=400000,
                             c_medical=500000, c_education=1000000, c_rent=0, c_life=1000000,
                             c_pension=2000000, c_donation=100000),
    "근로소득_03_고소득.pdf": dict(gross=95000000, laborDed=14750000, taxableBase=62000000,
                              calcTax=11000000, paid=12500000, decided=10200000, final=-2300000,
                              c_medical=3000000, c_education=5000000, c_rent=0, c_life=1000000,
                              c_pension=6000000, c_donation=1500000),
    "근로소득_04_중간_부분신고.pdf": dict(gross=42000000, laborDed=11550000, taxableBase=24000000,
                                  calcTax=2520000, paid=2000000, decided=2100000, final=100000,
                                  c_medical=200000, c_education=0, c_rent=3000000, c_life=500000,
                                  c_pension=0, c_donation=0),
    "근로소득_05_저소득_환급.pdf": dict(gross=26000000, laborDed=9090000, taxableBase=13000000,
                                  calcTax=858000, paid=600000, decided=300000, final=-300000,
                                  c_medical=0, c_education=0, c_rent=0, c_life=0,
                                  c_pension=0, c_donation=0),
}


# ─────────────────────────────────────────────────────────────
# 3) 사업소득 원천징수영수증 [별지23] (parseFreelancerText)
# ─────────────────────────────────────────────────────────────
def freelancer_lines(d):
    return [
        "■ 소득세법 시행규칙 [별지 제23호서식(3)] (3쪽 중 제1쪽)",
        "거주구분거주자",
        "징수의무자",
        "사업자등록번호126-81-44920",
        "소득자",
        "성 명홍길동",
        "주민등록번호000000-*******",
        "발생처 구분사업소득",
        "지급액(수입금액)",
        "보험모집 수입금액 계0",
        f"합 계 (124){won(d['gross'])}",
        "소득 금액",
        f"수입금액{won(d['gross'])}",
        f"소득금액{won(d['income'])}",
        f"소득세{won(d['decided'])}",
        "농어촌특별세0",
        "인적공제본 인1,500,000",
        "소득공제 등 종합한도 초과액0",
        f"결정세액{won(d['decided'])}",
        "종(전) 근무지0",
        f"차감 납부할 세액{won(d['final'])}",
    ]


FREELANCER = {
    "사업소득_01_환급.pdf": dict(gross=30000000, income=12000000, decided=600000, final=-390000),
    "사업소득_02_납부.pdf": dict(gross=60000000, income=30000000, decided=3400000, final=1420000),
    "사업소득_03_고소득_납부.pdf": dict(gross=120000000, income=70000000, decided=13500000, final=9540000),
    "사업소득_04_저소득_환급.pdf": dict(gross=15000000, income=6000000, decided=200000, final=-295000),
    "사업소득_05_중간_납부.pdf": dict(gross=45000000, income=22000000, decided=1900000, final=415000),
}


def main():
    made = []
    for fn, d in GANSO.items():
        made.append(render(fn, ganso_lines(d)))
    for fn, d in WONCHUN.items():
        made.append(render(fn, wonchun_lines(d)))
    for fn, d in FREELANCER.items():
        made.append(render(fn, freelancer_lines(d)))
    for p in made:
        print("created:", os.path.basename(p))
    print(f"\nTOTAL {len(made)} PDFs -> {OUT}")


if __name__ == "__main__":
    main()
