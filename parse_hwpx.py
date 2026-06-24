import sys
sys.stdout.reconfigure(encoding='utf-8')
import zipfile
import xml.etree.ElementTree as ET
import json
import os

HWPX_PATH = r'c:\Users\vedja\.gemini\antigravity\scratch\세끌\지식\문서\2025년 귀속 경비율 고시.hwpx'
JSON_DIR = r'c:\Users\vedja\.gemini\antigravity\scratch\세끌\지식_변환\JSON'
MD_DIR = r'c:\Users\vedja\.gemini\antigravity\scratch\세끌\지식_변환\마크다운'

os.makedirs(JSON_DIR, exist_ok=True)
os.makedirs(MD_DIR, exist_ok=True)

def parse_hwpx(file_path):
    tables_data = []
    with zipfile.ZipFile(file_path, 'r') as z:
        section_files = [n for n in z.namelist() if n.startswith('Contents/section') and n.endswith('.xml')]
        
        for sec_file in section_files:
            xml_content = z.read(sec_file).decode('utf-8')
            root = ET.fromstring(xml_content)
            
            ns = {'hp': 'http://www.hancom.co.kr/hwpml/2011/paragraph'}
            tables = root.findall('.//hp:tbl', ns)
            
            for tbl in tables:
                table_matrix = []
                rows = tbl.findall('.//hp:tr', ns)
                for tr in rows:
                    row_data = []
                    cells = tr.findall('.//hp:tc', ns)
                    for tc in cells:
                        texts = []
                        for t in tc.findall('.//hp:t', ns):
                            if t.text:
                                texts.append(t.text.strip())
                        cell_text = "\n".join(texts).strip()
                        row_data.append(cell_text)
                    if row_data:
                        table_matrix.append(row_data)
                
                if table_matrix:
                    tables_data.append(table_matrix)
    
    return tables_data

print("파싱 시작...")
try:
    extracted_tables = parse_hwpx(HWPX_PATH)
    print(f"총 {len(extracted_tables)}개의 표를 추출했습니다.")

    for i, table in enumerate(extracted_tables):
        table_name = f"16_2025년_귀속_경비율_고시_표{i+1}"
        json_data = {
            "파일명": table_name,
            "출처": "2025년 귀속 경비율 고시.hwpx",
            "행수": len(table),
            "데이터": table
        }
        json_path = os.path.join(JSON_DIR, f"{table_name}.json")
        with open(json_path, 'w', encoding='utf-8') as f:
            json.dump(json_data, f, ensure_ascii=False, indent=2)

        md_lines = [f"# {table_name}", ""]
        if table:
            header = table[0]
            md_lines.append("| " + " | ".join(header) + " |")
            md_lines.append("|" + "|".join(["---"] * len(header)) + "|")
            
            for row in table[1:]:
                padded_row = row + [""] * (len(header) - len(row))
                padded_row = [r.replace("\n", "<br>") for r in padded_row[:len(header)]]
                md_lines.append("| " + " | ".join(padded_row) + " |")

        md_path = os.path.join(MD_DIR, f"{table_name}.md")
        with open(md_path, 'w', encoding='utf-8') as f:
            f.write("\n".join(md_lines))

    print("완료!")
except Exception as e:
    print(f"오류 발생: {e}")
