#!/usr/bin/env python3
"""Package an unsigned Release app for user signing and check the resulting IPA."""
import argparse, hashlib, json, plistlib, struct, zipfile
from pathlib import Path

parser=argparse.ArgumentParser()
parser.add_argument('--app',type=Path,required=True)
parser.add_argument('--output',type=Path,required=True)
args=parser.parse_args()
app=args.app.resolve()
info=plistlib.loads((app/'Info.plist').read_bytes())
assert info['CFBundleSupportedPlatforms']==['iPhoneOS']
assert info['CFBundleShortVersionString']=='1.0.0'
assert info['CFBundleVersion']=='1'
assert info['MinimumOSVersion']=='26.0'
exe=app/info['CFBundleExecutable']
magic,cpu,_=struct.unpack('<III',exe.read_bytes()[:12])
assert magic==0xfeedfacf and cpu==0x100000c
for name in ['Assets.car','default-clap.wav','en.lproj/Localizable.strings','zh-Hans.lproj/Localizable.strings','PrivacyInfo.xcprivacy']:
    assert (app/name).is_file(),name
assert not (app/'_CodeSignature').exists()
assert not list(app.glob('*.debug.dylib'))
extensions=list((app/'PlugIns').glob('*.appex'))
assert len(extensions)==1
assert not list((app/'PlugIns').glob('*.xctest*'))
extension=extensions[0]
extension_info=plistlib.loads((extension/'Info.plist').read_bytes())
assert extension_info['CFBundleVersion']=='1'
assert extension_info['CFBundleShortVersionString']=='1.0.0'
assert extension_info['CFBundleIdentifier'].startswith(info['CFBundleIdentifier']+'.')
assert extension_info['NSExtension']['NSExtensionPointIdentifier']=='com.apple.widgetkit-extension'
assert info.get('NSSupportsLiveActivities') is True
assert 'audio' in info.get('UIBackgroundModes',[])
assert not (extension/'_CodeSignature').exists()
extension_exe=extension/extension_info['CFBundleExecutable']
assert struct.unpack('<II',extension_exe.read_bytes()[:8])==(0xfeedfacf,0x100000c)
for name in ['en.lproj/Localizable.strings','zh-Hans.lproj/Localizable.strings']:
    assert (extension/name).is_file(),name
for target in [app,extension]:
    metadata=json.loads((target/'Metadata.appintents/extract.actionsdata').read_bytes())
    intent=metadata['actions']['ClapSlateIntent']
    assert intent['openAppWhenRun'] is False
    assert intent['isDiscoverable'] is False
    assert 'com.apple.link.systemProtocol.AudioStarting' in intent['systemProtocols']
    assert 'com.apple.link.systemProtocol.SessionStarting' in intent['systemProtocols']
args.output.parent.mkdir(parents=True,exist_ok=True)
with zipfile.ZipFile(args.output,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as archive:
    for path in [app]+sorted(app.rglob('*')):
        archive.write(path,Path('Payload')/app.name/path.relative_to(app))
with zipfile.ZipFile(args.output) as archive:
    assert archive.testzip() is None
    assert all(n.startswith('Payload/') for n in archive.namelist())
    assert (archive.getinfo('Payload/'+app.name+'/'+exe.name).external_attr>>16)&0o111
report={'artifact':args.output.name,'version':info['CFBundleShortVersionString'],'build':info['CFBundleVersion'],
        'configuration':'Release','architecture':'arm64','minimum_ios':info['MinimumOSVersion'],
        'bundle_identifier':info['CFBundleIdentifier'],'signature':'unsigned; sign before installing',
        'size_bytes':args.output.stat().st_size,'zip_integrity':'PASS','payload_structure':'PASS',
        'resources':'native icon, bundled audio, en/zh-Hans localizations, privacy manifest, Live Activity extension present',
        'live_activity_extension':extension_info['CFBundleIdentifier'],
        'extension_version':'1.0.0 (1)',
        'intent_metadata':'App and extension both register background Live Activity + audio playback intent',
        'signing_note':'Main app and embedded appex must both be signed; do not strip the widget extension.',
        'sha256':hashlib.sha256(args.output.read_bytes()).hexdigest()}
args.output.with_suffix('.verification.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
