# 原生 SwiftUI 布局预览

这些图像由 macOS NSHostingView 离屏渲染实际共享的 Stage/Settings SwiftUI 视图生成，用于检查版面。不是 iPhone 截图，也不是 Xcode Canvas 验收记录。

- Classic-Landscape-*：按 iPhone 12 Pro 的 844×390 画布及安全区检查横屏。
- Classic-Portrait-*：390×844 画布及安全区。
- Classic-Settings-Light：1700 pt 高的设置分组布局检查；macOS 控件外观与 iOS 不同，音量控件使用布局代理。
- Classic-New-Project-*：实际 NameEditorPopover 内容，检查取消/保存按钮的等宽等高与形状。
- Classic-History-Actions-*：实际经典历史操作面板内容。以上两类图用传统 material 背景近似弹窗宿主，不包含系统气泡箭头，不作为 iPhone Popover 呈现或长按/拖放测试证据。

Liquid Glass 的系统合成层不能被此离屏方式完整捕获，其失败图片没有保留在交付预览中。原生玻璃效果与实际触控/动画必须在用户签名安装后核验。工程提供 Stage 的 #Preview 供 Xcode 查看。
