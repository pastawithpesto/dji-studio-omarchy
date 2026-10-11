import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.15
import Controls 1.0
import Config 1.0
import UIComponent

/**
 * AI 使用协议弹窗
 *
 * 基于 UIDialog Structured 布局（leftColumn 可滚动区 + bottomRight 按钮栏），
 * 底部"同意"按钮需滚动到底部后才可点击。
 * 点击同意后发出 agreementAccepted 信号并关闭。
 */
UIDialog {
    id: root

    signal destorySource()
    signal agreementAccepted()

    title: qsTr("pccut_roughcut_agreement_title")
    width: 600
    height: 540
    closeOnMaskClick: false
    layout: UIDialogLayout.Structured

    // 是否已滚动到底部
    property bool reachedBottom: false

    Component.onCompleted: {
        textArea.text = fileOperator.aiAgreementText();
        open()
    }

    onSigClosed: {
        root.destorySource()
    }

    onLeftColumnReachedBottom: {
        reachedBottom = true;
    }

    leftColumn: [
        TextArea {
            id: textArea
            Layout.fillWidth: true
            topPadding: 8
            bottomPadding: 8
            color: root.textColor
            font.pixelSize: 14
            wrapMode: TextArea.Wrap
            readOnly: true
            background: null
        }
    ]

    bottomRight: [
        UIButton {
            type: UIButtonType.Brand
            size: UIControlSize.L
            text: qsTr("pccut_roughcut_agreement_confirm")
            enabled: root.reachedBottom
            onClicked: {
                root.agreementAccepted();
                root.close();
            }
        }
    ]
}
