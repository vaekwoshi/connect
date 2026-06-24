# -*- coding: utf-8 -*-
import json
import os

transcript_path = r'C:\Users\vedja\.gemini\antigravity\brain\0c502d77-aadb-4ed9-938a-0931977c5f47\.system_generated\logs\transcript_full.jsonl'
output_dir = r'C:\Users\vedja\.gemini\antigravity\scratch\sekkul\plans'

os.makedirs(output_dir, exist_ok=True)

plans = []
with open(transcript_path, 'r', encoding='utf-8') as f:
    for line in f:
        if 'write_to_file' in line and 'implementation_plan.md' in line:
            try:
                data = json.loads(line)
                if 'tool_calls' in data:
                    for tc in data['tool_calls']:
                        if tc['name'] == 'write_to_file' and 'implementation_plan.md' in tc['args'].get('TargetFile', ''):
                            content = tc['args'].get('CodeContent')
                            if content and content not in plans:
                                plans.append(content)
            except:
                pass

for i, p in enumerate(plans):
    with open(os.path.join(output_dir, f'plan_v{i+1}.md'), 'w', encoding='utf-8') as f:
        f.write(p)

print(f'Extracted {len(plans)} unique plans.')
