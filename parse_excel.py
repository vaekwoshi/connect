import zipfile
import xml.etree.ElementTree as ET
import json
import os
import re

EXCEL_PATH = r'c:\Users\vedja\.gemini\antigravity\scratch\세끌\지식\엑셀\종합소득세_모의계산기-6.xlsx'
JSON_DIR = r'c:\Users\vedja\.gemini\antigravity\scratch\세끌\지식_변환\JSON'
MD_DIR = r'c:\Users\vedja\.gemini\antigravity\scratch\세끌\지식_변환\마크다운'

os.makedirs(JSON_DIR, exist_ok=True)
os.makedirs(MD_DIR, exist_ok=True)

def parse_sheet(z, sheet_file, shared_strings):
    """시트 XML을 파싱하여 {ref: {value, formula}} dict 반환"""
    ns = {'ns': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
    root = ET.fromstring(z.read(sheet_file))
    cells = root.findall('.//ns:c', ns)
    data = {}
    for c in cells:
        ref = c.get('r')
        t_attr = c.get('t')
        v_tag = c.find('ns:v', ns)
        f_tag = c.find('ns:f', ns)
        value = None
        formula = None
        if v_tag is not None and v_tag.text:
            if t_attr == 's':
                try:
                    value = shared_strings[int(v_tag.text)]
                except:
                    value = v_tag.text
            else:
                value = v_tag.text
        if f_tag is not None and f_tag.text:
            formula = f_tag.text
        if value is not None or formula is not None:
            data[ref] = {"value": value, "formula": formula}
    return data

def col_row(ref):
    """'C10' → ('C', 10)"""
    m = re.match(r'^([A-Z]+)(\d+)$', ref)
    if m:
        return m.group(1), int(m.group(2))
    return None, None

def to_col_index(col_str):
    """'A'→0, 'B'→1, 'AA'→26"""
    result = 0
    for ch in col_str:
        result = result * 26 + (ord(ch) - ord('A') + 1)
    return result - 1

def build_grid(cells_data):
    """셀 dict를 행/열 2D 리스트로 변환"""
    if not cells_data:
        return [], 0, 0
    max_row = max(int(re.search(r'\d+', ref).group()) for ref in cells_data)
    max_col = max(to_col_index(re.match(r'^([A-Z]+)', ref).group(1)) for ref in cells_data)
    grid = [[None] * (max_col + 1) for _ in range(max_row + 1)]
    for ref, data in cells_data.items():
        col_str, row_num = re.match(r'^([A-Z]+)(\d+)$', ref).groups()
        ci = to_col_index(col_str)
        ri = int(row_num)
        grid[ri][ci] = data
    return grid, max_row, max_col

with zipfile.ZipFile(EXCEL_PATH) as z:
    # 시트 이름 파악
    wb_root = ET.fromstring(z.read('xl/workbook.xml'))
    wb_ns = {'ns': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
    sheets = wb_root.findall('.//ns:sheet', wb_ns)
    sheet_names = [s.get('name') for s in sheets]
    print(f"Sheets found: {sheet_names}")

    # 공유 문자열(Shared Strings) 파싱 (UTF-8 강제)
    ss_raw = z.read('xl/sharedStrings.xml').decode('utf-8')
    ss_root = ET.fromstring(ss_raw)
    ss_ns = {'ns': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
    shared_strings = []
    for si in ss_root.findall('.//ns:si', ss_ns):
        parts = [t.text for t in si.findall('.//ns:t', ss_ns) if t.text]
        shared_strings.append("".join(parts))

    print(f"Shared strings parsed: {len(shared_strings)}")
    print("First 5 strings:", shared_strings[:5])

    # 시트별 처리
    sheet_files = ['xl/worksheets/sheet1.xml', 'xl/worksheets/sheet2.xml']
    for idx, (sheet_name, sheet_file) in enumerate(zip(sheet_names, sheet_files)):
        if sheet_file not in z.namelist():
            continue
        cells_data = parse_sheet(z, sheet_file, shared_strings)
        
        # 구조화된 행 리스트 생성
        rows_output = []
        if cells_data:
            max_row = max(int(re.search(r'\d+', ref).group()) for ref in cells_data)
            for row_num in range(1, max_row + 1):
                row_cells = {ref: d for ref, d in cells_data.items()
                             if re.match(rf'^[A-Z]+{row_num}$', ref)}
                if row_cells:
                    row_list = []
                    for ref in sorted(row_cells, key=lambda r: to_col_index(re.match(r'^([A-Z]+)', r).group(1))):
                        d = row_cells[ref]
                        entry = {"cell": ref}
                        if d["value"] is not None:
                            entry["value"] = d["value"]
                        if d["formula"] is not None:
                            entry["formula"] = "=" + d["formula"]
                        row_list.append(entry)
                    rows_output.append({"row": row_num, "cells": row_list})

        clean_name = re.sub(r'[\/:*?"<>| ]', '_', sheet_name)
        
        # JSON 저장
        json_data = {
            "시트명": sheet_name,
            "설명": f"종합소득세 모의계산기 - {sheet_name} 시트",
            "행목록": rows_output
        }
        json_path = os.path.join(JSON_DIR, f"15_종합소득세_모의계산기_{clean_name}.json")
        with open(json_path, 'w', encoding='utf-8') as f:
            json.dump(json_data, f, ensure_ascii=False, indent=2)

        # Markdown 저장
        md_lines = [
            f"# 종합소득세 모의계산기 - {sheet_name} 시트\n",
            "| 셀 | 값 | 수식 |",
            "|---|---|---|",
        ]
        for row_data in rows_output:
            for cell_data in row_data["cells"]:
                val = str(cell_data.get("value", "")).replace("\n", " ").strip()
                formula = cell_data.get("formula", "")
                if val or formula:
                    md_lines.append(f"| {cell_data['cell']} | {val} | {formula} |")

        md_path = os.path.join(MD_DIR, f"15_종합소득세_모의계산기_{clean_name}.md")
        with open(md_path, 'w', encoding='utf-8') as f:
            f.write("\n".join(md_lines))

        print(f"→ 완료: {clean_name} ({len(rows_output)}개 행)")

print("All done!")
