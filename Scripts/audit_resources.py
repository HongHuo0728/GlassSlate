#!/usr/bin/env python3
"""Check shipped assets and (optionally) compiler-extracted localization coverage."""
from pathlib import Path
import json, sys, wave
root=Path(__file__).resolve().parents[1]
catalog=json.loads((root/'GlassSlate/Resources/Localizable.xcstrings').read_text())
for key, entry in catalog['strings'].items():
    assert set(entry['localizations']) == {'en','zh-Hans'}, key
    for localization in entry['localizations'].values():
        units=[localization['stringUnit']] if 'stringUnit' in localization else [p['stringUnit'] for p in localization['variations']['plural'].values()]
        assert all(u['state']=='translated' and u['value'] for u in units),key
with wave.open(str(root/'GlassSlate/Resources/default-clap.wav'),'rb') as audio:
    duration=audio.getnframes()/audio.getframerate()
    assert audio.getnchannels()==1 and audio.getsampwidth()==2 and audio.getframerate()==48000
    assert 0 < duration < 1
icon=root/'GlassSlate/GlassSlate.icon'
document=json.loads((icon/'icon.json').read_text())
layers=[layer for group in document['groups'] for layer in group['layers']]
assert len(layers)==4
for layer in layers: assert (icon/'Assets'/layer['image-name']).is_file()
extracted=set()
if len(sys.argv)>1:
    for file in Path(sys.argv[1]).rglob('*.stringsdata'):
        data=json.loads(file.read_text())
        for table in data.get('tables',{}).values():
            extracted.update(row['key'] for row in table)
    assert extracted, 'No compiler extraction results found'
    assert not extracted-set(catalog['strings']), sorted(extracted-set(catalog['strings']))
report={'result':'PASS','localization_entries':len(catalog['strings']), 'locales':['en','zh-Hans'],
        'compiler_extracted_keys':len(extracted),'missing_translations':[],
        'default_audio':{'duration_seconds':duration,'format':'48000 Hz mono PCM16'},
        'native_icon_layers':len(layers),'icon_source':'GlassSlate/GlassSlate.icon'}
print(json.dumps(report,ensure_ascii=False,indent=2))
