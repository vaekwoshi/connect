import zipfile
import xml.etree.ElementTree as ET
import json
import os
import re

def clean_text(text):
    if not text: return ""
    return re.sub(r'\s+', ' ', str(text)).strip()

def extract_tables_from_docx(docx_path):
    with zipfile.ZipFile(docx_path) as z:
        xml_content = z.read('word/document.xml')
    
    root = ET.fromstring(xml_content)
    ns = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
    
    tables = root.findall('.//w:tbl', ns)
    parsed_tables = []
    
    for tbl in tables:
        table_data = []
        for row in tbl.findall('.//w:tr', ns):
            row_data = []
            for cell in row.findall('.//w:tc', ns):
                texts = [t.text for t in cell.findall('.//w:t', ns) if t.text]
                row_data.append(clean_text("".join(texts)))
            table_data.append(row_data)
        parsed_tables.append(table_data)
        
    return parsed_tables

def main():
    docx_path = r'c:\Users\vedja\.gemini\antigravity\scratch\세끌\지식\문서\1. To_Be_변환파일_수록형식_종합소득세[20260511]_최종_5차.docx'
    json_dir = r'c:\Users\vedja\.gemini\antigravity\scratch\세끌\지식_변환\JSON'
    md_dir = r'c:\Users\vedja\.gemini\antigravity\scratch\세끌\지식_변환\마크다운'
    
    os.makedirs(json_dir, exist_ok=True)
    os.makedirs(md_dir, exist_ok=True)
    
    tables = extract_tables_from_docx(docx_path)
    if not tables:
        print("No tables found!")
        return

    # 1. 서식코드 -> 서식명 매핑 추출 (첫 번째 표)
    form_map = {}
    for row in tables[0]:
        if len(row) >= 2:
            name, code = row[0], row[1]
            if code and code.startswith('C') or code.startswith('M') or code.startswith('F') or code.startswith('P') or code.startswith('A'):
                form_map[code.strip()] = name.strip()

    print(f"Loaded {len(form_map)} form mappings.")

    # 2. 레코드 스펙 테이블 추출
    # 구조: parsed_data[서식코드] = [ { "자료구분": "51", "항목들": [...] }, ... ]
    parsed_data = {}
    
    for idx, table in enumerate(tables):
        if not table: continue
        
        # 헤더 식별
        header = table[0]
        if "한글명" in header and "TYPE" in header and "길이" in header:
            # 컬럼 인덱스 찾기
            try:
                col_name = header.index("한글명")
                col_type = header.index("TYPE")
                col_len = header.index("길이")
                col_acc = header.index("누적길이")
            except ValueError:
                continue # 필수 컬럼 없으면 패스
            
            col_note = -1
            for i, h in enumerate(header):
                if "비" in h and "고" in h:
                    col_note = i
                    break
            
            col_check = -1
            if "점검내용" in header:
                col_check = header.index("점검내용")

            current_form_code = None
            current_record_type = None
            items = []
            
            for row in table[1:]:
                # 셀 개수가 부족하면 패스
                if len(row) <= max(col_name, col_type, col_len, col_acc):
                    continue
                    
                name = row[col_name]
                t_type = row[col_type]
                length = row[col_len]
                acc = row[col_acc]
                note = row[col_note] if col_note != -1 and len(row) > col_note else ""
                check = row[col_check] if col_check != -1 and len(row) > col_check else ""
                
                if name == "자료구분":
                    current_record_type = check.strip() if check.strip() else note.strip()
                    # 점검내용 쪽에 보통 51, 52 등이 적혀있음
                elif name == "서식코드":
                    current_form_code = check.strip() if check.strip() else note.strip()

                items.append({
                    "항목명": name,
                    "타입": t_type,
                    "길이": length,
                    "누적길이": acc,
                    "비고": note,
                    "점검내용": check
                })
            
            if current_form_code:
                # 서식코드가 여러개 섞여있거나 지저분한 경우 정리 (예: C110700)
                match = re.search(r'[A-Z]\d{6}', current_form_code)
                if match:
                    code = match.group(0)
                    if code not in parsed_data:
                        parsed_data[code] = []
                    
                    parsed_data[code].append({
                        "자료구분": current_record_type or "알수없음",
                        "항목들": items
                    })

    # 3. 파일 생성
    count = 0
    for code, records in parsed_data.items():
        name = form_map.get(code, "서식명_없음")
        clean_name = re.sub(r'[\/:*?"<>|]', '', name).replace(' ', '_')
        
        # JSON 저장
        json_filename = os.path.join(json_dir, f"{code}_{clean_name}.json")
        with open(json_filename, 'w', encoding='utf-8') as f:
            json.dump({
                "서식코드": code,
                "서식명": name,
                "레코드목록": records
            }, f, ensure_ascii=False, indent=2)
            
        # Markdown 저장
        md_filename = os.path.join(md_dir, f"{code}_{clean_name}.md")
        with open(md_filename, 'w', encoding='utf-8') as f:
            f.write(f"# {code} - {name}\n\n")
            for record in records:
                f.write(f"## 자료구분: {record['자료구분']}\n\n")
                f.write("| 항목명 | 타입 | 길이 | 누적길이 | 비고 | 점검내용 |\n")
                f.write("|---|---|---|---|---|---|\n")
                for item in record["항목들"]:
                    f.write(f"| {item['항목명']} | {item['타입']} | {item['길이']} | {item['누적길이']} | {item['비고']} | {item['점검내용']} |\n")
                f.write("\n")
        count += 1
        
    print(f"Successfully generated {count} JSON and MD files.")

if __name__ == '__main__':
    main()
