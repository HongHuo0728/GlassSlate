#!/usr/bin/env python3
import json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
translations = '''Production|片名 / 制作名称
Roll|卷号
Scene|场次
Shot|镜头
Take|条次
Director|导演
Cameraman|摄影师
Date|日期
System|跟随系统
Light|浅色
Dark|深色
Cancel|取消
Delete|删除
Save|保存
Done|完成
OK|好
Retry|重试
Empty|空白
History|历史记录
Settings|设置
Appearance|外观
Shooting|拍摄
Language|语言
Sound|声音
Auto-increment Take|拍板后自动 Take +1
Haptics|触觉反馈
New slate|新建场记板
Undo|撤销
Preview|试听
Import sound|导入音效
Classic clap|经典拍板音效
Custom sound|自定义音效
Restore classic sound|恢复经典音效
System output volume|系统输出音量
Open App Settings|打开 App 系统设置
System follows your iPhone appearance. Home Screen icon appearance is controlled by iOS.|“跟随系统”会跟随 iPhone 外观。主屏幕图标外观由 iOS 控制。
After saving a snapshot, numeric Takes advance by one. 009 becomes 010; 02B stays 02B.|保存拍板快照后，仅纯数字条次加一。009 变为 010；02B 保持不变。
Follows your iPhone language. To choose English or Simplified Chinese for GlassSlate, open the native App settings.|默认跟随 iPhone 语言。要为 GlassSlate 选择英文或简体中文，请打开系统中的 App 设置。
WAV and M4A recommended. Up to 30 seconds and 50 MB. Imported audio is copied onto this iPhone.|推荐 WAV、M4A，最长 30 秒、最大 50 MB。导入音效会复制并保存在此 iPhone 上。
Use this system control to adjust volume. Check Bluetooth and wired output. Clap playback can sound even in Silent Mode. GlassSlate never changes system volume automatically.|请使用此系统控件调节音量，并检查蓝牙与有线输出。拍板声可在静音模式下播放。GlassSlate 不会自动修改系统音量。
Your saved data could not be opened. It has not been erased.|无法打开已保存的数据。数据未被删除。
Enter a value|请输入内容
Clap slate|拍板
Saves a snapshot and plays the clap sound.|保存当前场记板快照并播放拍板音效。
Delete slate?|删除这条场记记录？
This removes this snapshot from history.|将从历史记录中删除此快照。
New blank slate?|新建空白场记板？
Your current working slate will be replaced. History is kept.|将替换当前正在编辑的场记板，历史记录会保留。
Unable to complete action|无法完成操作
Unable to save|无法保存
History and settings|历史记录与设置
READY FOR ACTION|准备开拍
Unlock fields|解锁字段
Lock fields and keep screen awake|锁定字段并保持屏幕常亮
Locked|已锁定
Unlocked|已解锁
Fields locked · screen stays awake|字段已锁定 · 屏幕保持常亮
Tap the striped clapper to mark a take|轻触顶部斜纹拍板，记录一次拍摄
Tap to edit|轻触编辑
Unlock to edit|解锁后可编辑
Double tap to edit|轻点两下以编辑
Slate deleted|已删除场记记录
Take marked|已记录本条拍摄
Untitled production|未命名制作
Double tap to restore. Long press for deletion options.|轻点两下以恢复，长按显示删除确认。
Restore slate|恢复场记板
Close history|关闭历史记录
Your film starts here|你的影片从这里开始
No slates yet|暂无场记记录
Tap the striped clapper. Each take will appear here.|轻触顶部斜纹拍板，每次拍摄都会记录在这里。
Audio is unavailable. Please try again.|音频暂时不可用，请重试。
Custom sound is missing or damaged. Using the classic sound.|自定义音效丢失或损坏，已回退到经典拍板音效。
Audio session could not be released.|无法释放音频会话。
An unused sound file could not be removed.|无法清理一个不再使用的音效文件。
The bundled clap sound could not be found.|找不到内置拍板音效。
Choose a playable audio file up to 30 seconds and 50 MB.|请选择可播放的音频文件，最长 30 秒、最大 50 MB。
The sound could not play. Check your audio output.|无法播放音效，请检查音频输出设备。
Could not save changes. Please try again.|无法保存更改，请重试。
Could not restore this slate. Please try again.|无法恢复这条场记记录，请重试。
Could not delete this slate. Please try again.|无法删除这条场记记录，请重试。
Could not start the clap. Check audio output and available storage.|无法开始拍板，请检查音频输出与可用存储空间。
The sound could not play. The slate was saved.|音效播放失败，场记记录已保存。
Could not open Settings. Open GlassSlate in the Settings app.|无法打开系统设置，请在“设置”App 中打开 GlassSlate。
Could not import audio. Choose a playable local file.|无法导入音效，请选择可播放的本地文件。
Could not import or play audio. Check the file and audio output.|无法导入或播放音效，请检查文件与音频输出。
Liquid Glass|液态玻璃
Changes apply after restarting GlassSlate. Off uses a separately designed frosted and matte interface inspired by iOS 18.|重启 GlassSlate 后生效。关闭后使用单独设计的 iOS 18 风格毛玻璃与哑光界面。
Restart required|需要重启 App
Tactile feedback for fields, controls, drawers, saves and deletion, with a firm impact at clap contact.|字段、控件、抽屉、保存与删除均提供触感反馈，拍板接触瞬间提供清晰的碰撞反馈。
Close GlassSlate from the App Switcher, then reopen it to apply the new interface. Your slates and settings are kept.|请从多任务界面关闭 GlassSlate，再重新打开以应用新界面。场记记录与设置会保留。
A save is still in progress. Please try again.|正在保存，请稍后重试。
The sound could not play. The slate will still be saved.|音效播放失败，场记记录仍会保存。
The clap could not be saved. Your working slate is unchanged. Please try again.|拍板记录保存失败，当前场记板未更改，请重试。
Name|名称
New project|新建项目
Project name|项目名称
Projects|项目
Drop slates here|将场记记录拖到这里
All slates|全部场记记录
Unfiled slates|未归类场记记录
Rename|重命名
Rename slate|重命名场记记录
Move to project|移动到项目
Delete slate|删除场记记录
Delete…|删除…
Drop a slate here to move it into this project.|将场记记录拖到这里即可移入此项目。
This project is no longer available.|此项目已不可用。
Enter a project name.|请输入项目名称。
Live Activities|实时活动
Clap from the Lock Screen or an expanded Dynamic Island. Availability and duration are controlled by iOS.|在锁屏或展开的灵动岛中一键拍板。显示方式与持续时长由 iOS 控制。
Live Activity has not started yet.|实时活动尚未启动。
Live Activities are off.|实时活动已关闭。
Live Activities are disabled in iOS Settings.|iOS 系统设置中已禁用实时活动。
Live Activity is active. Visibility and duration are managed by iOS.|实时活动已启动，显示方式与持续时长由 iOS 管理。
Live Activity could not start. Check iOS settings and widget signing.|无法启动实时活动，请检查系统设置与小组件扩展签名。
Mark a take, save its slate and play the selected clap sound.|标记一次拍摄、保存场记记录并播放所选拍板音效。
Open GlassSlate once before using the clap button.|请先打开一次 GlassSlate，再使用拍板按钮。
Live Activities are turned off in GlassSlate.|GlassSlate 中的实时活动已关闭。
Could not start the clap. Please try again.|无法开始拍板，请重试。
GlassSlate|GlassSlate
GlassSlate · 1.0.0 (1)|GlassSlate · 1.0.0 (1)'''
strings={}
for line in translations.splitlines():
    en,zh=line.split('|',1)
    strings[en]={"extractionState":"manual","localizations":{lang:{"stringUnit":{"state":"translated","value":value}} for lang,value in [('en',en),('zh-Hans',zh)]}}
strings['%lld slates']={"extractionState":"manual","localizations":{
    "en":{"variations":{"plural":{form:{"stringUnit":{"state":"translated","value":value}} for form,value in [('one','%lld slate'),('other','%lld slates')]}}},
    "zh-Hans":{"stringUnit":{"state":"translated","value":"%lld 条场记记录"}}
}}
(root/'GlassSlate/Resources/Localizable.xcstrings').write_text(json.dumps({"sourceLanguage":"en","strings":strings,"version":"1.0"},ensure_ascii=False,indent=2)+'\n')
(root/'GlassSlate/Assets.xcassets/Contents.json').write_text(json.dumps({"info":{"author":"xcode","version":1}},indent=2))
(root/'GlassSlate/Assets.xcassets/AppIcon.appiconset/Contents.json').write_text(json.dumps({"images":[],"info":{"author":"xcode","version":1}},indent=2))
print(f'Generated {len(strings)} bilingual entries')
