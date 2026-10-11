import QtQuick 2.15
import QtQuick.Controls

/**
 * @brief 模拟 Widget 的 ClickFocus 策略
 * @details 当 TextField/TextInput 拥有焦点时，点击其区域外的任意位置自动清除焦点。
 *          作为 contentRect 等容器的子项使用，anchors.fill: parent 即可。
 * @date: 2026-04-26
 */
MouseArea {
    id: root
    anchors.fill: parent
    z: 999

    onPressed: (mouse) => {
        var fi = root.Window.activeFocusItem
        if (fi && (fi instanceof TextField || fi instanceof TextInput)) {
            var pt = mapToItem(fi, mouse.x, mouse.y)
            if (!fi.contains(pt)) {
                parent.forceActiveFocus()
            }
        }
        mouse.accepted = false
    }
}
