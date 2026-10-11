import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.15
import UIComponent

// 大疆灵云服务用户协议详情弹窗。
UIDialog {
    id: root

    signal destorySource()

    title: qsTr("pccut_cloud_service_agreement_detail_title")
    width: 600
    height: 473
    z: 200
    closeOnMaskClick: false
    layout: UIDialogLayout.Structured

    property bool reachedBottom: false

    Component.onCompleted: {
        agreementText.text = fileOperator.cloudAlbumAgreementText()
        open()
    }

    onSigClosed: {
        root.destorySource()
    }

    onLeftColumnReachedBottom: {
        reachedBottom = true
    }

    leftColumn: [
        TextArea {
            id: agreementText
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
            text: qsTr("pccut_cloud_service_agreement_detail_btn_confirm")
            enabled: root.reachedBottom
            onClicked: root.close()
        }
    ]
}
