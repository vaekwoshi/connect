# -*- coding: utf-8 -*-
import json
import os

transcript_path = r'C:\Users\vedja\.gemini\antigravity\brain\0c502d77-aadb-4ed9-938a-0931977c5f47\.system_generated\logs\transcript_full.jsonl'
target_file = r'C:\Users\vedja\.gemini\antigravity\brain\0c502d77-aadb-4ed9-938a-0931977c5f47\implementation_plan.md'

content_to_restore = None

with open(transcript_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()
    for line in reversed(lines):
        if 'write_to_file' in line and 'implementation_plan.md' in line and 'Toss' not in line and 'A/B/C' not in line:
            try:
                data = json.loads(line)
                if 'tool_calls' in data:
                    for tc in data['tool_calls']:
                        if tc['name'] == 'write_to_file' and 'implementation_plan.md' in tc['args'].get('TargetFile', ''):
                            content_to_restore = tc['args'].get('CodeContent')
                            if content_to_restore and 'Toss' not in content_to_restore:
                                break
            except:
                pass
        if content_to_restore:
            break

if content_to_restore:
    with open(target_file, 'w', encoding='utf-8') as f:
        f.write(content_to_restore)
    print('SUCCESS: Restored implementation_plan.md')
else:
    print('FAILED: Could not find previous content')
