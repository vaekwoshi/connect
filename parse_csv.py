import csv
import json
import sys

input_path = r'c:\Users\vedja\.gemini\antigravity\scratch\세끌\지식\엑셀\국민건강보험공단_건강보험 보험료등급조견표_개편_20230101.csv'
output_path = r'c:\Users\vedja\.gemini\antigravity\scratch\세끌\지식_변환\JSON\건강보험_등급조견표_개편_샘플.json'

try:
    # try reading with euc-kr
    with open(input_path, 'r', encoding='euc-kr') as f:
        reader = csv.reader(f)
        header = next(reader)
        
        # print header without printing to stdout to avoid cp949 encoding errors on windows console
        header_str = " | ".join(header)
        
        data = []
        for i, row in enumerate(reader):
            if i >= 10: # 10개만 샘플
                break
            data.append(dict(zip(header, row)))
            
    with open(output_path, 'w', encoding='utf-8') as out:
        json.dump({"헤더": header, "샘플데이터": data}, out, ensure_ascii=False, indent=2)
    print("Success")
except Exception as e:
    print("Error:", e)
