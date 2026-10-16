import AppKit
import SwiftUI

// MARK: - 菜单构建辅助（闭包式 target-action）

final class ActionItem: NSObject {
    let fire: () -> Void
    init(_ fire: @escaping () -> Void) { self.fire = fire }
    @objc func run() { fire() }
}

final class TrayMenuBuilder {
    private var actions: [ActionItem] = []

    /// 普通菜单项
    func item(_ title: String, fire: @escaping () -> Void) -> NSMenuItem {
        let m = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let a = ActionItem(fire)
        m.target = a
        m.action = #selector(ActionItem.run)
        actions.append(a)
        return m
    }

    /// 需要事后改标题的菜单项（fire 收到菜单项自身）
    func mutableItem(_ title: String, fire: @escaping (NSMenuItem) -> Void) -> NSMenuItem {
        let m = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let a = ActionItem { [weak m] in if let m = m { fire(m) } }
        m.target = a
        m.action = #selector(ActionItem.run)
        actions.append(a)
        return m
    }

    /// 在父菜单里开一个子菜单
    func submenu(_ title: String, in parent: NSMenu) -> NSMenu {
        let mi = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let sub = NSMenu(title: title)
        mi.submenu = sub
        parent.addItem(mi)
        return sub
    }
}

// MARK: - 应用入口

let widgets: [DesktopWidget] = [CompassWidget(), TaijiWidget()]

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let widgets: [DesktopWidget]
    private var statusItem: NSStatusItem?
    /// 必须强持有：所有菜单项的 target（ActionItem）都托管在这里，
    /// builder 一释放 target 全变 nil，菜单点什么都不响应
    private var menuBuilder: TrayMenuBuilder?

    init(widgets: [DesktopWidget]) { self.widgets = widgets }

    func applicationDidFinishLaunching(_ notification: Notification) {
        for w in widgets { w.show() }
        buildStatusItem()
    }

    func buildStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let img = widgets.first?.makeBadge() {
            img.size = NSSize(width: 18, height: 18)   // 菜单栏标准图标尺寸，不设会被 64pt 大图撑爆
            item.button?.image = img
        }
        let menu = NSMenu()
        let mb = TrayMenuBuilder()
        menuBuilder = mb

        for w in widgets {
            let sub = mb.submenu(w.name, in: menu)

            sub.addItem(mb.mutableItem(w.visible ? "隐藏" : "显示") { m in
                w.toggleVisible()
                m.title = w.visible ? "隐藏" : "显示"
            })
            sub.addItem(mb.mutableItem("暂停") { m in
                w.paused.toggle()
                m.title = w.paused ? "继续" : "暂停"
            })
            sub.addItem(mb.item("还原默认") {
                w.resetToDefaults()
            })
            w.addQuickItems(mb, sub)
            sub.addItem(NSMenuItem.separator())
            sub.addItem(mb.item("参数设置…") {
                w.openSettings()
            })
        }
        menu.addItem(NSMenuItem.separator())
        menu.addItem(mb.item("退出") {
            NSApp.terminate(nil)
        })

        item.menu = menu
        statusItem = item
    }
}

// 进程入口本就在主线程，assumeIsolated 把引导段接进 MainActor
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate(widgets: widgets)
    app.delegate = delegate
    app.setActivationPolicy(.accessory)   // 无 Dock 图标，只有菜单栏
    app.run()
}
