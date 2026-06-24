import openpyxl

EXCEL_PATH = r'지식\엑셀\종합소득세_모의계산기-6.xlsx'

try:
    wb = openpyxl.load_workbook(EXCEL_PATH, data_only=True)
    sheet = wb['모의계산기']
    print("엑셀 시트 로드 성공!")
except Exception as e:
    print(f"에러 발생: {e}")
    # openpyxl이 없을 수 있으므로 설치 명령 실행 준비를 위한 출력
    print("openpyxl 라이브러리가 없는 것 같습니다.")
