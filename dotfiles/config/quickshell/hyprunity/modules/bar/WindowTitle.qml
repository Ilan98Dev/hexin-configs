import QtQuick
import QtQuick.Layouts
import Quickshell.Wayland
import qs.config
import qs.components

Txt {
    readonly property var activeWindow: ToplevelManager.activeToplevel

    text: activeWindow ? activeWindow.title : ""
    elide: Text.ElideRight
    color: Theme.subtext
    maximumLineCount: 1
    Layout.maximumWidth: Config.bar.windowTitleWidth
}
