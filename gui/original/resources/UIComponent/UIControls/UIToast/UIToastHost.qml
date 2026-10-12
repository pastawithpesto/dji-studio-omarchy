import QtQuick
import QtQuick.Layouts
import UIComponent

// UIToastHost
//   全屏覆盖式容器，负责堆叠/调度 Toast。
//   推荐用法：在 ApplicationWindow 根级放一个，业务方通过 id 调用。
//
//   ApplicationWindow {
//       UIToastHost { id: toastHost }
//       UIButton { onClicked: toastHost.show("已保存") }
//   }
//
//   API:
//       show(text)
//       show({text, type, size, duration, position, modal})
//
//   行为:
//     - 同位置纵向堆叠（新的入下方）
//     - 同位置末项同 text 在 dedupeWindow 内重复触发，合并去重
//     - modal=true 显示半透明蒙层，阻断后方点击；默认不阻断
Item {
    id: host
    anchors.fill: parent
    z: 9999

    readonly property int _dedupeWindow: 500   // ms
    property int _modalCount: 0

    ListModel { id: topModel }
    ListModel { id: centerModel }
    ListModel { id: bottomModel }

    function show(opts) {
        if (typeof opts === "string") opts = { text: opts }
        const text = opts.text || ""
        if (!text) return

        const pos = opts.position || "center"
        const m = pos === "top" ? topModel : pos === "bottom" ? bottomModel : centerModel

        const now = Date.now()
        // 去重判断放在"同 stack 末项"，避免全局字典累积导致内存泄漏
        if (m.count > 0) {
            const last = m.get(m.count - 1)
            if (last.text === text && (now - last._createdAt) < host._dedupeWindow) return
        }

        const cfg = {
            _createdAt: now,
            text:       text,
            type:       opts.type === undefined ? UIToastType.Info : opts.type,
            size:       opts.size === undefined ? UIControlSize.M : opts.size,
            duration:   opts.duration === undefined ? UIToastDuration.Medium : opts.duration,
            modal:      opts.modal === true
        }
        if (cfg.modal) host._modalCount += 1
        m.append(cfg)
    }

    function _release(model, index) {
        if (model.get(index).modal) host._modalCount = Math.max(0, host._modalCount - 1)
        model.remove(index)
    }

    Loader {
        anchors.fill: parent
        active: host._modalCount > 0
        sourceComponent: Component {
            Rectangle {
                color: UIColors.colorFillMask
                // modal mask 需 grab 全部 pointer event 阻断后方交互，MouseArea 是 Qt 传统做法
                MouseArea { anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton }
            }
        }
    }

    Column {
        id: topStack
        spacing: UISize.sizeXS
        anchors.top: parent.top
        anchors.topMargin: UISize.sizeMD
        anchors.horizontalCenter: parent.horizontalCenter
        Repeater {
            model: topModel
            delegate: UIToast {
                anchors.horizontalCenter: parent.horizontalCenter
                text:     model.text
                type:     model.type
                size:     model.size
                duration: model.duration
                onClosed: host._release(topModel, index)
            }
        }
    }

    Column {
        id: centerStack
        spacing: UISize.sizeXS
        anchors.centerIn: parent
        Repeater {
            model: centerModel
            delegate: UIToast {
                anchors.horizontalCenter: parent.horizontalCenter
                text:     model.text
                type:     model.type
                size:     model.size
                duration: model.duration
                onClosed: host._release(centerModel, index)
            }
        }
    }

    Column {
        id: bottomStack
        spacing: UISize.sizeXS
        anchors.bottom: parent.bottom
        anchors.bottomMargin: UISize.sizeMD
        anchors.horizontalCenter: parent.horizontalCenter
        Repeater {
            model: bottomModel
            delegate: UIToast {
                anchors.horizontalCenter: parent.horizontalCenter
                text:     model.text
                type:     model.type
                size:     model.size
                duration: model.duration
                onClosed: host._release(bottomModel, index)
            }
        }
    }
}
