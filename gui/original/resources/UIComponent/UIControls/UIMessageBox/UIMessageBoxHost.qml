import QtQuick
import UIComponent

// UIMessageBoxHost
//   全局唯一弹窗调度器。同时只显示一个 MessageBox,新请求排队。
//
//   推荐用法:在 ApplicationWindow 根级放一个,业务方通过 id 调用。
//
//   ApplicationWindow {
//       UIMessageBoxHost { id: msgBoxHost }
//       ...
//       UIButton {
//           onClicked: {
//               const handle = dialogHost.show({
//                   title: "删除草稿?",
//                   text:  "删除后无法恢复",
//                   buttons: [
//                       { text: "取消", role: "cancel" },
//                       { text: "确定", role: "accept", type: UIButtonType.BrandGrad }
//                   ],
//                   onClosed: function(role, checked) {
//                       console.log("user chose", role, checked)
//                   }
//               })
//               // 进度类弹窗:handle.update({ progress: 0.5 })
//               // 程序主动关:handle.close("cancel")
//           }
//       }
//   }
Item {
    id: host

    property var _queue: []
    property var _current: null

    Component {
        id: dialogComp
        UIMessageBox {}
    }

    function show(opts) {
        opts = opts || {}
        const entry = { opts: opts, instance: null, handle: null }

        // 提前把 handle 暴露给调用方,即使还在排队
        entry.handle = {
            update: function(patch) {
                if (entry.instance) {
                    if (patch.progress    !== undefined) entry.instance.progress    = patch.progress
                    if (patch.text        !== undefined) entry.instance.text        = patch.text
                    if (patch.title       !== undefined) entry.instance.title       = patch.title
                    if (patch.spinnerText !== undefined) entry.instance.spinnerText = patch.spinnerText
                } else {
                    Object.assign(entry.opts, patch)
                }
            },
            close: function(role) {
                if (entry.instance) entry.instance._dismiss(role || "cancel")
                else {
                    const i = host._queue.indexOf(entry)
                    if (i >= 0) host._queue.splice(i, 1)
                }
            }
        }

        host._queue.push(entry)
        host._tryNext()
        return entry.handle
    }

    function _tryNext() {
        if (host._current) return
        if (host._queue.length === 0) return
        const entry = host._queue.shift()
        const opts = entry.opts
        const props = {
            size:             opts.size === undefined ? UIControlSize.M : opts.size,
            msgType:          opts.msgType === undefined ? UIMessageBoxType.Normal : opts.msgType,
            title:            opts.title || "",
            text:             opts.text || "",
            checkbox:         opts.checkbox || null,
            buttons:          opts.buttons || [{ text: qsTr("确定"), role: "accept", type: UIButtonType.Brand }],
            progress:         opts.progress === undefined ? -2 : opts.progress,
            spinnerText:      opts.spinnerText || "",
            closeOnMaskClick: !!opts.closeOnMaskClick
        }
        if (opts.minHeight !== undefined) props.minHeight = opts.minHeight
        if (opts.contentMaxWidth !== undefined) props.contentMaxWidth = opts.contentMaxWidth
        if (opts.buttonMaxWidth !== undefined) props.buttonMaxWidth = opts.buttonMaxWidth
        const inst = dialogComp.createObject(host, props)
        entry.instance = inst
        host._current = entry

        inst.sigDismissed.connect(function(role, checked) {
            if (typeof opts.onClosed === "function") {
                try { opts.onClosed(role, checked) }
                catch (e) { console.warn("UIMessageBox onClosed handler threw:", e) }
            }
        })
        // 关闭动画播完后 destroy + 推下一个
        inst.closed.connect(function() {
            host._current = null
            entry.instance = null
            inst.destroy()
            Qt.callLater(host._tryNext)
        })
        inst.open()
    }
}
