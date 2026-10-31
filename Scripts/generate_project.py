#!/usr/bin/env python3
"""Generate the native app, Live Activity extension, and unit-test targets without dependencies."""
from pathlib import Path
import hashlib, json
root=Path(__file__).resolve().parents[1]
project=root/'GlassSlate.xcodeproj'; project.mkdir(exist_ok=True)
objects={}
def uid(name): return hashlib.sha1(name.encode()).hexdigest()[:24].upper()
def add(name,value): objects[uid(name)]=value; return uid(name)
def q(value): return json.dumps(str(value))
def array(items): return '('+', '.join(items)+',)' if items else '()'
shared=sorted(p.relative_to(root).as_posix() for p in (root/'Shared').glob('*.swift'))
sources=sorted(p.relative_to(root).as_posix() for p in (root/'GlassSlate').rglob('*.swift'))+shared
widget_sources=sorted(p.relative_to(root).as_posix() for p in (root/'GlassSlateLiveActivity').glob('*.swift'))+shared+['GlassSlate/Models/ActivityPayloadText.swift']
tests=sorted(p.relative_to(root).as_posix() for p in (root/'GlassSlateTests').glob('*.swift'))
resources=['GlassSlate/Resources/default-clap.wav','GlassSlate/Resources/Localizable.xcstrings','GlassSlate/Resources/PrivacyInfo.xcprivacy','GlassSlate/Assets.xcassets','GlassSlate/GlassSlate.icon']
widget_resources=['GlassSlate/Resources/Localizable.xcstrings','GlassSlate/Resources/PrivacyInfo.xcprivacy']
file_ids=[]
version_file=add('versionconfig','isa = PBXFileReference; lastKnownFileType = text.xcconfig; path = "Config/Version.xcconfig"; sourceTree = "<group>";')
file_ids.append(version_file)
for path in sorted(set(sources+widget_sources+tests+resources+['GlassSlate/Info.plist','GlassSlateLiveActivity/Info.plist'])):
 ext=Path(path).suffix
 filetype={'.swift':'sourcecode.swift','.wav':'audio.wav','.xcstrings':'text.json.xcstrings','.xcassets':'folder.assetcatalog','.icon':'folder.iconcomposer.icon','.plist':'text.plist.xml','.xcprivacy':'text.xml'}[ext]
 file_ids.append(add('file:'+path,f'isa = PBXFileReference; lastKnownFileType = {q(filetype)}; path = {q(path)}; sourceTree = "<group>";'))
app_product=add('product','isa = PBXFileReference; explicitFileType = wrapper.application; path = GlassSlate.app; sourceTree = BUILT_PRODUCTS_DIR;')
widget_product=add('widgetproduct','isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; path = GlassSlateLiveActivity.appex; sourceTree = BUILT_PRODUCTS_DIR;')
test_product=add('testproduct','isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = GlassSlateTests.xctest; sourceTree = BUILT_PRODUCTS_DIR;')
products=add('products',f'isa = PBXGroup; children = {array([app_product,widget_product,test_product])}; name = Products; sourceTree = "<group>";')
group=add('group',f'isa = PBXGroup; children = {array(file_ids+[products])}; sourceTree = "<group>";')
def phase(name,kind,paths):
 builds=[]
 for path in paths: builds.append(add('build:'+name+':'+path,f'isa = PBXBuildFile; fileRef = {uid("file:"+path)};'))
 return add(name,f'isa = {kind}; buildActionMask = 2147483647; files = {array(builds)}; runOnlyForDeploymentPostprocessing = 0;')
app_phases=[phase('sources','PBXSourcesBuildPhase',sources),phase('frameworks','PBXFrameworksBuildPhase',[]),phase('resources','PBXResourcesBuildPhase',resources)]
widget_phases=[phase('widgetsources','PBXSourcesBuildPhase',widget_sources),phase('widgetframeworks','PBXFrameworksBuildPhase',[]),phase('widgetresources','PBXResourcesBuildPhase',widget_resources)]
test_phases=[phase('testsources','PBXSourcesBuildPhase',tests),phase('testframeworks','PBXFrameworksBuildPhase',[])]
embedfile=add('embedwidgetfile',f'isa = PBXBuildFile; fileRef = {widget_product}; settings = {{ ATTRIBUTES = (CodeSignOnCopy, RemoveHeadersOnCopy); }};')
app_phases.append(add('embedwidget',f'isa = PBXCopyFilesBuildPhase; buildActionMask = 2147483647; dstPath = ""; dstSubfolderSpec = 13; files = {array([embedfile])}; name = "Embed App Extensions"; runOnlyForDeploymentPostprocessing = 0;'))
common={'SDKROOT':'iphoneos','IPHONEOS_DEPLOYMENT_TARGET':'26.0','SWIFT_VERSION':'6.0','CLANG_ENABLE_MODULES':'YES','CLANG_ENABLE_OBJC_ARC':'YES','SWIFT_STRICT_CONCURRENCY':'complete','ENABLE_USER_SCRIPT_SANDBOXING':'YES','GCC_C_LANGUAGE_STANDARD':'gnu17','CLANG_WARN_DOCUMENTATION_COMMENTS':'YES'}
identity={'TARGETED_DEVICE_FAMILY':'1,2','SUPPORTED_PLATFORMS':'iphoneos','CODE_SIGN_STYLE':'Automatic','SWIFT_EMIT_LOC_STRINGS':'YES','LOCALIZATION_PREFERS_STRING_CATALOGS':'YES'}
app=dict(identity,PRODUCT_NAME='GlassSlate',PRODUCT_BUNDLE_IDENTIFIER='com.glassslate.app.dev',INFOPLIST_FILE='GlassSlate/Info.plist',GENERATE_INFOPLIST_FILE='NO',SUPPORTS_MACCATALYST='NO',ASSETCATALOG_COMPILER_APPICON_NAME='GlassSlate',LD_RUNPATH_SEARCH_PATHS='$(inherited) @executable_path/Frameworks')
widget=dict(identity,PRODUCT_NAME='GlassSlateLiveActivity',PRODUCT_BUNDLE_IDENTIFIER='com.glassslate.app.dev.LiveActivity',INFOPLIST_FILE='GlassSlateLiveActivity/Info.plist',GENERATE_INFOPLIST_FILE='NO',APPLICATION_EXTENSION_API_ONLY='YES',SKIP_INSTALL='YES',SWIFT_ACTIVE_COMPILATION_CONDITIONS='WIDGET_EXTENSION',LD_RUNPATH_SEARCH_PATHS='$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks')
test=dict(identity,PRODUCT_NAME='GlassSlateTests',PRODUCT_BUNDLE_IDENTIFIER='com.glassslate.app.dev.tests',GENERATE_INFOPLIST_FILE='YES',TEST_HOST='$(BUILT_PRODUCTS_DIR)/GlassSlate.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/GlassSlate',BUNDLE_LOADER='$(TEST_HOST)',LD_RUNPATH_SEARCH_PATHS='$(inherited) @executable_path/Frameworks @loader_path/Frameworks')
def configs(name,settings):
 ids=[]
 for config in ['Debug','Release']:
  values=dict(settings)
  values.update(DEBUG_INFORMATION_FORMAT='dwarf' if config=='Debug' else 'dwarf-with-dsym',SWIFT_OPTIMIZATION_LEVEL='-Onone' if config=='Debug' else '-O')
  if config=='Debug': values.update(ENABLE_TESTABILITY='YES',SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG '+values.get('SWIFT_ACTIVE_COMPILATION_CONDITIONS','')+' $(inherited)')
  body=' '.join(f'{k} = {q(v)};' for k,v in values.items())
  ids.append(add(name+config,f'isa = XCBuildConfiguration; baseConfigurationReference = {version_file}; buildSettings = {{ {body} }}; name = {config};'))
 return add(name+'configs',f'isa = XCConfigurationList; buildConfigurations = {array(ids)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
pc=configs('project',common); ac=configs('app',app); wc=configs('widget',widget); tc=configs('test',test)
def dependency(name,target_name,target_title):
 proxy=add(name+'proxy',f'isa = PBXContainerItemProxy; containerPortal = {uid("project")}; proxyType = 1; remoteGlobalIDString = {uid(target_name)}; remoteInfo = {q(target_title)};')
 return add(name+'dependency',f'isa = PBXTargetDependency; target = {uid(target_name)}; targetProxy = {proxy};')
widget_dep=dependency('widget','widgettarget','GlassSlateLiveActivity')
app_dep=dependency('app','target','GlassSlate')
def target(key,name,configs,phases,product,kind,deps):
 return add(key,f'isa = PBXNativeTarget; buildConfigurationList = {configs}; buildPhases = {array(phases)}; buildRules = (); dependencies = {array(deps)}; name = {name}; productName = {name}; productReference = {product}; productType = {q(kind)};')
wid=target('widgettarget','GlassSlateLiveActivity',wc,widget_phases,widget_product,'com.apple.product-type.app-extension',[])
aid=target('target','GlassSlate',ac,app_phases,app_product,'com.apple.product-type.application',[widget_dep])
tid=target('testtarget','GlassSlateTests',tc,test_phases,test_product,'com.apple.product-type.bundle.unit-test',[app_dep])
attributes=f'{aid} = {{ CreatedOnToolsVersion = 26.5; }}; {wid} = {{ CreatedOnToolsVersion = 26.5; }}; {tid} = {{ CreatedOnToolsVersion = 26.5; TestTargetID = {aid}; }};'
add('project',f'isa = PBXProject; attributes = {{ LastUpgradeCheck = 2650; TargetAttributes = {{ {attributes} }}; }}; buildConfigurationList = {pc}; compatibilityVersion = "Xcode 16.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, "zh-Hans", Base); mainGroup = {group}; productRefGroup = {products}; projectDirPath = ""; projectRoot = ""; targets = {array([aid,wid,tid])};')
(project/'project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 77; objects = {\n'+'\n'.join(f'{k} = {{ {v} }};' for k,v in objects.items())+f'\n}}; rootObject = {uid("project")}; }}\n')
scheme=project/'xcshareddata/xcschemes'; scheme.mkdir(parents=True,exist_ok=True)
ref=f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{aid}" BuildableName="GlassSlate.app" BlueprintName="GlassSlate" ReferencedContainer="container:GlassSlate.xcodeproj"/>'
tref=f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{tid}" BuildableName="GlassSlateTests.xctest" BlueprintName="GlassSlateTests" ReferencedContainer="container:GlassSlate.xcodeproj"/>'
(scheme/'GlassSlate.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2650" version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{ref}</BuildActionEntry></BuildActionEntries></BuildAction><TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB"><Testables><TestableReference skipped="NO">{tref}</TestableReference></Testables></TestAction><LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="NO"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></LaunchAction><ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></ProfileAction><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>''')
version_settings=dict(line.split('=',1) for line in (root/'Config/Version.xcconfig').read_text().splitlines() if '=' in line and not line.lstrip().startswith('//'))
version_settings={k.strip():v.strip() for k,v in version_settings.items()}
print(f'Generated app ({len(sources)} sources), Live Activity ({len(widget_sources)} sources), and {len(tests)} test files; version {version_settings["MARKETING_VERSION"]} ({version_settings["CURRENT_PROJECT_VERSION"]})')
