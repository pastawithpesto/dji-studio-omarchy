import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls
import Config 1.0
import Controls 1.0
import QtQuick.Dialogs
import Qt5Compat.GraphicalEffects
import Qt.labs.platform
import VideoConfig 1.0
import MediaTypeModel 1.0
import "../../menubar"
import app_qrc 1.0
import Nova 1.0

LightPopup {
    id: pop
    // width: 600
    // height: 339
    width: lightWindow.width
    height: lightWindow.height
    
    dim: false
    property real gaussianX: 10
    property real gaussianY: 10
    // 水平间隔
    property real hItemMargin: 12
    // 垂直间隔
    property real vItemMargin: 16
    // 标题对齐线
    //property real labelGuideline: Math.max(fileNameTxt.width, filePathTxt.width) + hItemMargin
    // 截图的文件名
    property string jpgFileName: ""
    property alias exportSuperPath: filePathRectangle.contentText
    property real selectResolutionType: -1
    property var resolution
    signal startShot(string fileSuperPath, string fileName, var resolution, bool useCylinder, bool imageLoadSuccess,
                     bool isFileNameChange, bool exportAsDng)
     //记录当前缩略图的地址
    property string coverpath:""
    // 预览图是否加载成功
    property bool imageLoadSuccess: false

    // 打开弹窗时缓存当前截图片段源路径，用于判断是否可提供 DNG 导出
    property string screenShotSourcePathForExport: ""

    readonly property bool dngSourceAvailable: {
        if (!screenShotSourcePathForExport || screenShotSourcePathForExport.length === 0)
            return false;
        return screenShotSourcePathForExport.toLowerCase().endsWith(".dng");
    }

    //记录普通缩略图和全景缩略图是否已经生成避免重复生成
    property bool imageGenerateSuccess: false
    property string imageGeneratePath:""
    property bool imagePanoGenerateSuccess: false
    property string imagePanoGeneratePath:""

    // 获取当前播放的画面
    signal getCurDispalyFrameSig();

    // 响应调用底层接口获取到播放器当前帧事件
    function onImageSaved(path){
        pop.coverpath = path
        imageLoader.sourceComponent = picComponent;
        imageLoadSuccess = true;
    }

    // 调用截帧保存兜底
    function generatePic(){
        if (!imagePanoGenerateSuccess || !imageGenerateSuccess) {
            screenShot.generatePic(false, pop.isPreViewScreenShot);
        } else {
            reloadImage(false);
        }
    }

    onOpened: {
        imageGenerateSuccess = false;
        imagePanoGenerateSuccess = false;
        refreshCover(panoCheckBox.checked);
        content.enabled = false;
    }

    onClosed: {
        imageLoader.active = false; // 卸载当前组件
        content.enabled = true;
    }
    contentItem: Item{
        MouseArea {
            anchors.fill: parent
            onClicked: {
                //closeSignal();
                //close();
            }
        }

        Rectangle {
            id: rectangle
            width: 600
            height: 370
            anchors.verticalCenter: parent.verticalCenter
            anchors.horizontalCenter: parent.horizontalCenter
            radius: 8
            clip: true
            color: Colors.color_2F3032
            border.width:1
            border.color:Colors.color_454649
             MouseArea {
                anchors.fill: parent
                onClicked: {}
            }
            WindowTitleBar {
                id: titleBar
                height: 40
                width: parent.width
                title: qsTr("pccut_player_screenshot")
                onCloseClick: {
                    close();
                }
            }

            //时间轴截图
            Rectangle {
                id: picRectangle
                width: 212
                height: 159
                color: Colors.color_transparent
                radius: 6
                clip: true // 启用裁剪以实现圆角效果
                anchors {
                    left: parent.left
                    leftMargin: 28
                    top: titleBar.bottom
                    topMargin: 24
                }
                Component {
                    id: picComponent
                    LightClipRectangle {
                        id:imageWrapper
                        anchors.fill: parent
                        color: Colors.color_000000
                        radius: [6,6,6,6]
                        Image {
                            anchors.fill: parent
                            cache: false
                            source: "file:///" + pop.coverpath
                            fillMode: Image.PreserveAspectCrop
                        }


                    }
                }
                Component {
                    id: picLoadingComponent
                    LightClipRectangle {
                        id:imageLoadingWrapper
                        anchors.fill: parent
                        color: Colors.color_000000
                        radius: [6,6,6,6]
                        Image {
                            anchors.fill: parent
                            cache: false
                            source: translationHandler.isChineseLang() ? "qrc:/icons/cover_loading.svg" : "qrc:/icons/cover_loading_en.svg"
                            sourceSize: Qt.size(57, 57)
                            fillMode: Image.Pad
                        }
                    }
                }

                Loader {
                    id: imageLoader
                    anchors.fill: parent
                    sourceComponent: picLoadingComponent
                }
            }

            // DNG 导出说明（仅平面 + 选 DNG 时显示）
            Text {
                id: dngExportHint
                width: picRectangle.width
                anchors {
                    left: picRectangle.left
                    right: picRectangle.right
                    top: picRectangle.bottom
                    topMargin: 12
                }
                visible: (videoCheckBox.checked || panoCheckBox.checked) && dngSourceAvailable
                         && formatCombo.currentIndex === 1
                wrapMode: Text.WordWrap
                text: qsTr("pccut_player_screenshot_dng_tip")
                font.pixelSize: 11
                color: Colors.color_666666
            }

            //提示文字
            Text {
                id: picTips
                width: picRectangle.width
                anchors {
                    left: picRectangle.left
                    top: dngExportHint.visible ? dngExportHint.bottom : picRectangle.bottom
                    topMargin: dngExportHint.visible ? 8 : 12
                }
                wrapMode: Text.WordWrap
                text: qsTr("pccut_export_panorama_tips_4")
                font.pixelSize: 11
                color: Colors.color_666666
            }
            // 类型选择
            Rectangle {
                id: typeRectangle

                anchors {
                    left: parent.left
                    leftMargin: 268
                    top: titleBar.bottom
                    topMargin: 24
                    right: parent.right
                    rightMargin: 28
                }
                height: 16
                color: Colors.color_transparent
                Text {
                    id: typeText
                    anchors {
                        left: parent.left
                        top: parent.top
                        bottom: parent.bottom
                    }
                    width: 51
                    horizontalAlignment: Text.AlignLeft
                    verticalAlignment: Text.AlignVCenter
                    maximumLineCount: 2
                    wrapMode: Text.WrapAnywhere
                    font.pixelSize: 12
                    color: Colors.color_CCCCCC
                    text: qsTr("pccut_export_as")
                }
                CheckBox {
                    id:videoCheckBox
                    text: qsTr("pccut_media_filter_image")
                    anchors {
                        left: typeText.right
                        leftMargin: 12
                    }
                    checked: true
                    anchors.verticalCenter: parent.verticalCenter
                    indicator: Rectangle {
                        implicitWidth: 16
                        implicitHeight: 16
                        anchors.left: videoCheckBox.left
                        anchors.verticalCenter: parent.verticalCenter
                        color:  Colors.color_transparent
                        radius: 8
                        Image {
                            visible: true
                            anchors.fill: parent
                            source: videoCheckBox.checked?"qrc:/app_qrc/icons/icon_radio_selected.svg":"qrc:/icons/icon_radio_button_no.svg"
                            sourceSize: Qt.size(parent.width, parent.height)
                        }
                    }
                    MouseArea {
                        anchors.fill: videoCheckBox
                        onClicked: {
                            if(videoCheckBox.checked){
                                return;
                            }else{
                                videoCheckBox.checked = true;
                                panoCheckBox.checked = false;
                                formatCombo.currentIndex = 0;
                                refreshCover(false);
                                refreshResolution();
                            }
                        }
                    }
                    contentItem: Text {
                        text: videoCheckBox.text
                        font.pixelSize: 12
                        color: Colors.color_EEEEEE
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: videoCheckBox.indicator.width
                        clip: true
                    }
                }
                CheckBox {
                    property bool canUse: editorManager.isPanoFragment(pop.isPreViewScreenShot)
                    id:panoCheckBox
                    text: qsTr("pccut_export_panoramic_image")
                    anchors {
                        left: videoCheckBox.right
                        leftMargin: 45
                        right:parent.right
                    }
                    checked: false
                    anchors.verticalCenter: parent.verticalCenter
                    indicator: Rectangle {
                        implicitWidth: 16
                        implicitHeight: 16
                        anchors.left: panoCheckBox.left
                        anchors.verticalCenter: parent.verticalCenter
                        color:  Colors.color_transparent
                        radius: 8
                        opacity: panoCheckBox.canUse?1:0.4
                        Image {
                            visible: true
                            anchors.fill: parent
                            source:panoCheckBox.checked?"qrc:/app_qrc/icons/icon_radio_selected.svg":"qrc:/icons/icon_radio_button_no.svg"
                            sourceSize: Qt.size(parent.width, parent.height)
                        }
                    }
                    onVisibleChanged: {
                        if (visible) {
                            let judge = editorManager.isPanoFragment(pop.isPreViewScreenShot) && (editorManager.getCurVideoType() !== MediaType.DUSS_REMUX_RECORD_PANO_VIDEO_SEMI
                                                                        && editorManager.getCurVideoType() !== MediaType.DUSS_REMUX_RECORD_PANO_VIDEO_BULLET_TIME);
                            canUse = judge
                        }
                    }
                    MouseArea {
                        anchors.fill: panoCheckBox
                        hoverEnabled: true // 启用悬停检测
                        onClicked: {
                            if(panoCheckBox.checked){
                                return;
                            }else{
                                if(panoCheckBox.canUse){
                                    videoCheckBox.checked = false;
                                    panoCheckBox.checked = true;
                                    formatCombo.currentIndex = 0;
                                    refreshCover(true);
                                    refreshResolution()
                                }
                            }
                        }
                        onEntered: {
                            if(!panoCheckBox.canUse){
                                hoverRectangle.visible = true; // 鼠标进入时显示
                            }
                        }
                        onExited: {
                            hoverRectangle.visible = false; // 鼠标离开时隐藏
                        }
                    }
                    contentItem: HoverableText {
                        text: panoCheckBox.text
                        font.pixelSize: 12
                        cursorChanged: false
                        elide: Text.ElideRight
                        wrapMode: Text.NoWrap
                        horizontalAlignment: Text.AlignLeft
                        color: panoCheckBox.canUse?Colors.color_EEEEEE:Colors.color_444444
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: panoCheckBox.indicator.width
                        anchors {
                            left:parent.left
                            leftMargin: 6
                            right: parent.right
                        }
                        onClicked: {
                            if(panoCheckBox.checked){
                                return;
                            }else{
                                if(panoCheckBox.canUse){
                                    videoCheckBox.checked = false;
                                    panoCheckBox.checked = true;
                                    formatCombo.currentIndex = 0;
                                    refreshCover(true);
                                    refreshResolution()
                                }
                            }
                        }
                    }
                }
                Rectangle {
                    id:hoverRectangle
                    implicitWidth: 68
                    implicitHeight: 16
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    color:  Colors.color_transparent
                    visible: false
                    Image {
                        anchors.fill: parent
                        source:"qrc:/icons/icon_no_support.svg"
                        sourceSize: Qt.size(parent.width, parent.height)
                    }
                }
            }
            // 文件名
            BaseTextField{
                id:fileNameRectangle
                titleText:qsTr("pccut_player_screenshot_name")
                height:28
                showSuffix:true
                spacing:12
                suffixText: (formatCombo.currentIndex === 0) ? ".jpg" : ".dng"
                anchors {
                    left: parent.left
                    leftMargin: 268
                    top: typeRectangle.bottom
                    topMargin: 22
                    right: parent.right
                    rightMargin: 28
                }
                // onTextValueChanged:(value) => {
                //     editorInfo.name = value;
                // }
                
            }

            // 文件格式（当前片段为 DNG 时提供 JPG / DNG）
            Item {
                id: fileFormatSlot
                anchors {
                    left: parent.left
                    leftMargin: 268
                    top: fileNameRectangle.bottom
                    topMargin: 16
                    right: parent.right
                    rightMargin: 28
                }
                height: ((videoCheckBox.checked || panoCheckBox.checked) && dngSourceAvailable && !CommonUtils.isWindows()) ? 28 : 0

                Rectangle {
                    id: fileFormatRectangle
                    anchors.fill: parent
                    visible: parent.height > 0
                    color: Colors.color_transparent

                    Text {
                        id: fileFormatLabel
                        anchors {
                            left: parent.left
                            top: parent.top
                            bottom: parent.bottom
                        }
                        width: 51
                        horizontalAlignment: Text.AlignLeft
                        verticalAlignment: Text.AlignVCenter
                        maximumLineCount: 2
                        wrapMode: Text.WrapAnywhere
                        font.pixelSize: 12
                        color: Colors.color_CCCCCC
                        text: qsTr("pccut_player_screenshot_dng_format")
                    }

                    ComboBox {
                        id: formatCombo
                        anchors {
                            left: fileFormatLabel.right
                            leftMargin: 12
                            top: parent.top
                            bottom: parent.bottom
                            right: parent.right
                        }
                        model: ["JPG", "DNG"]
                        currentIndex: 0
                        hoverEnabled: true
                        background: Rectangle {
                            color: formatCombo.hovered ? Colors.color_68696D : Colors.color_454649
                            radius: RadiusConfig.radius_4_8
                        }
                        contentItem: Text {
                            leftPadding: 8
                            rightPadding: formatCombo.indicator.width + formatCombo.spacing
                            text: formatCombo.displayText
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: Colors.color_FFFFFF
                            verticalAlignment: Text.AlignVCenter
                        }
                        delegate: ItemDelegate {
                            width: formatCombo.width - 8
                            anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
                            height: 28
                            padding: 0
                            leftPadding: 8
                            hoverEnabled: true
                            contentItem: Item {
                                Image {
                                    id: selectIcon
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    width: 16
                                    height: 16
                                    source: "qrc:/icons/selectlist.svg"
                                    sourceSize: Qt.size(16, 16)
                                    visible: formatCombo.currentIndex === index
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    leftPadding: 16 + 8
                                    text: modelData
                                    font.pixelSize: 12
                                    color: Colors.color_FFFFFF
                                }
                            }
                            background: Rectangle {
                                color: hovered ? Colors.color_68696D : Colors.color_transparent
                                radius: RadiusConfig.radius_4_8
                            }
                        }
                        popup: Popup {
                            y: formatCombo.height + 4
                            width: formatCombo.width
                            padding: 4
                            contentItem: ListView {
                                implicitHeight: contentHeight
                                model: formatCombo.popup.visible ? formatCombo.delegateModel : null
                                clip: true
                            }
                            background: Rectangle {
                                color: Colors.color_454649
                                radius: RadiusConfig.radius_4_8
                            }
                        }
                        indicator: Image {
                            x: formatCombo.width - width - 8
                            y: formatCombo.topPadding + (formatCombo.availableHeight - height) / 2
                            width: 20
                            height: 20
                            source: "qrc:/icons/adjustment/icon_drop_down_menu_expand.svg"
                            sourceSize: Qt.size(20, 20)
                        }
                    }
                }
            }

            // 路径选择
            BaseSelectionWithButton{
                id:filePathRectangle
                titleText:qsTr("pccut_player_screenshot_path")
                btnText:qsTr("pccut_player_screenshot_modify")
                height:28
                anchors {
                    left: parent.left
                    leftMargin: 268
                    top: fileFormatSlot.bottom
                    topMargin: 16
                    right: parent.right
                    rightMargin: 28
                }
                onCustomClick:() => {
                    fileDialog.open();
                }        
            }
            BaseSpliter { // 标题栏分隔线
                id: line2
                anchors {
                    top: filePathRectangle.bottom
                    topMargin: 16
                    left: parent.left
                    leftMargin: 268
                }
                width: 304
            }
            Rectangle {
                id: resolutionRectangle
                property bool resolutionSelecting: false
                anchors {
                    left: parent.left
                    leftMargin: 268
                    top: line2.bottom
                    topMargin: 16
                    right: parent.right
                    rightMargin: 28
                }

                height: 28
                color: Colors.color_transparent

                Text {
                    id: resolutionNameText
                    anchors {
                        left: parent.left
                        top: parent.top
                        bottom: parent.bottom
                    }
                    width: 51
                    horizontalAlignment: Text.AlignLeft
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 12
                    color: Colors.color_CCCCCC
                    maximumLineCount: 2
                    wrapMode: Text.WrapAnywhere
                    text: qsTr("pccut_pr_reframe_resolution")
                    Accessible.role: Accessible.Button
                    Accessible.description: "filmexport_exportresolutionname"
                }

                Rectangle {
                    id: resolutionChoose
                    anchors {
                        left: resolutionNameText.right
                        leftMargin: 12
                        top: parent.top
                        bottom: parent.bottom
                        right: parent.right
                    }
                    color: {
                        if (resolutionChooseArea.containsMouse) {
                            return Colors.color_68696D
                        } else if (resolutionRectangle.resolutionSelecting) {
                            return Colors.color_454649
                        } else {
                            return Colors.color_454649
                        }
                    }
                    radius: RadiusConfig.radius_4_8
                    Accessible.role: Accessible.Button
                    Accessible.description: "filmexport_exportresolutiontune"

                    Image {
                        id: resolutionChooseImage

                        anchors {
                            right: parent.right
                            rightMargin: 8
                            verticalCenter: parent.verticalCenter
                        }
                        width: 20
                        height: 20
                        source: resolutionRectangle.resolutionSelecting ? "qrc:/icons/adjustment/icon_drop_down_menu_collapse.svg" : "qrc:/icons/adjustment/icon_drop_down_menu_expand.svg"
                        sourceSize: Qt.size(20, 20)
                    }

                    Text {
                        id: resolutionChooseBtn
                        anchors {
                            left: parent.left
                            leftMargin: 8
                            top: parent.top
                            bottom: parent.bottom
                            right: resolutionChooseImage.left
                        }
                        horizontalAlignment: Text.AlignLeft
                        verticalAlignment: Text.AlignVCenter
                        color: Colors.color_FFFFFF
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        id: resolutionChooseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            resolutionRectangle.resolutionSelecting = true;
                            resolutionSettingPanel.active = true
                            resolutionSettingPanel.item.show(resolutionChoose, selectResolutionType,panoCheckBox.checked?true:false,true);
                        }
                    }
                }

                Connections {
                    target: resolutionSettingPanel.item
                    function onSelectedItemSignal(title, value, type) {
                        resolutionRectangle.resolutionSelecting = false;
                        if(!panoCheckBox.checked){
                            resolutionChooseBtn.text = title + " - " + value;
                        }else{
                            resolutionChooseBtn.text = title;
                        }

                        //resolutionLabel.text = value;
                        selectResolutionType = type;
                        resolution = videoConfig.getImgQmlItemByResolutionType(selectResolutionType);
                    }
                    function onCloseSignal() {
                        resolutionRectangle.resolutionSelecting = false;
                    }
                }
            }

            Item {
                id: actionButton
                height: 77
                width: 184

                anchors {
                    top: resolutionRectangle.bottom
                    right: parent.right
                    bottom: parent.bottom
                    rightMargin: 28
                }
                BaseConfirmBtn {
                    id: confirmBtn
                    btnText:qsTr("pccut_player_screenshot_yes")
                    width: 88
                    height: 28
                    type: 0
                    anchors {
                        top:parent.top
                        topMargin:40
                        right: parent.right
                    }
                    onCustomClick:() => {
                        const exportAsDng = dngSourceAvailable && (videoCheckBox.checked || panoCheckBox.checked)
                                && (formatCombo.currentIndex === 1);
                        startShot(filePathRectangle.contentText, fileNameRectangle.valueTextCom.text, resolution,
                                  panoCheckBox.checked ? true : false, imageLoadSuccess,
                                  jpgFileName !== fileNameRectangle.valueTextCom.text, exportAsDng);
                        lightSetting.save(Instance.key_screen_shot_save_path, filePathRectangle.contentText)
                        fileOperator.setQMLScreenShotType(panoCheckBox.checked?true:false);
                        fileOperator.setQMLScreenShotResolution(selectResolutionType);
                        close();
                    }
                }

                BaseConfirmBtn {
                    id: cancelBtn
                    btnText:qsTr("pccut_player_screenshot_cancel")
                    width: 88
                    height: 28
                    type: 1
                    anchors {
                        top:parent.top
                        topMargin:40
                        left: parent.left
                    }
                    onCustomClick:() => {
                        close();
                    }
                }
            }

        }
    }

    FolderDialog {
        id: fileDialog
        currentFolder: fileOperator.FileUrlWithPreFix(exportSuperPath)
        onAccepted: {
            // 获取文件夹路径
            let rawPath = fileDialog.folder.toString()

            // 移除前缀 "file:///"
            let cleanedPath = rawPath.replace(/^file:\/\//, "")

            // 在 Windows 上移除开头的 "/"（如果有）
            if (Qt.platform.os === "windows") {
                cleanedPath = cleanedPath.replace(/^\//, "")
            }
            //检查文件夹读写权限
            if(!fileOperator.hasFileCreateAccess(cleanedPath)){
                toast.showToast(qsTr("pccut_editor_fail_warn_5"));
                return;
            }
            // 设置路径
            exportSuperPath = cleanedPath
        }
    }
    Connections {
        target: globalSignal
        function onExportImageSaved(path,canvas){
            // windows下全景截图和本地截图逻辑不同，导致全景图延迟生成替换了底层当前帧截图画面
            // 所以增加这个判断，如果此时是windows端，并且已经走到本地截图逻辑，就不走这里
            if(CommonUtils.isWindows() && !panoCheckBox.checked){
                return;
            }
            switch(canvas){
                case VideoConfig.CANVASRATIOTYPE_2_1:{
                    imagePanoGenerateSuccess = true;
                    imagePanoGeneratePath = path;
                    picTips.visible = true;
                    break;
                }
                default:{
                    imageGenerateSuccess = true;
                    imageGeneratePath = path;
                }
            }
            pop.coverpath = path
            imageLoader.sourceComponent = picComponent;
            imageLoadSuccess = true;
        }
    }
    function reloadImage(isUseCylinder){
        if(isUseCylinder){
            picTips.visible = true;
            pop.coverpath = imagePanoGeneratePath;
        }else{
            pop.coverpath = imageGeneratePath;
        }
        imageLoader.sourceComponent = picComponent;
        imageLoadSuccess = true;
    }
    //刷新缩略图
    function refreshCover(useCylinder){
        picRectangle.width = 212;
        picRectangle.height = 117;
        picRectangle.anchors.leftMargin = 28;
        imageLoader.sourceComponent = picLoadingComponent;
        imageLoader.active = true; // 重新激活Loader
        picTips.visible = false;
         switch(editorManager.getCurrentCanvasType()){
            case VideoConfig.CANVASRATIOTYPE_1_1:{
                picRectangle.width = 212;
                picRectangle.height = 212;
                picRectangle.anchors.leftMargin = 28;
                break;
            }
            case VideoConfig.CANVASRATIOTYPE_3_4:{
                picRectangle.width = 159;
                picRectangle.height = 212;
                picRectangle.anchors.leftMargin = 54;
                break;
            }
            case VideoConfig.CANVASRATIOTYPE_4_3:{
                picRectangle.width = 212;
                picRectangle.height = 159;
                picRectangle.anchors.leftMargin = 28;
                break;
            }
            case VideoConfig.CANVASRATIOTYPE_9_16:{
                picRectangle.width = 117;
                picRectangle.height = 212;
                picRectangle.anchors.leftMargin = 76;
                break;
            }
            case VideoConfig.CANVASRATIOTYPE_16_9:
            case VideoConfig.CANVASRATIOTYPE_16_9_SETTING:{
                picRectangle.width = 212;
                picRectangle.height = 117;
                picRectangle.anchors.leftMargin = 28;
                break;
            }
            default:{
                break;
            }
        }

        if(useCylinder){
            picRectangle.width = 212;
            picRectangle.height = 106;
            picRectangle.anchors.leftMargin = 28;
        }else{
            getCurDispalyFrameSig();
            return;
        }

        if (!imagePanoGenerateSuccess || !imageGenerateSuccess) {
            screenShot.generatePic(useCylinder, pop.isPreViewScreenShot);
        } else {
            reloadImage(useCylinder);
        }
    }
    //刷新切换的图片类型
    function refreshScreenShotType(){
        var saveType = fileOperator.getQMLScreenShotType();
        var canUse = editorManager.isPanoFragment(pop.isPreViewScreenShot) && (editorManager.getCurVideoType() !== MediaType.DUSS_REMUX_RECORD_PANO_VIDEO_SEMI
                                                                               && editorManager.getCurVideoType() !== MediaType.DUSS_REMUX_RECORD_PANO_VIDEO_BULLET_TIME)
        if(saveType === 0 || !canUse) {
            videoCheckBox.checked = true;
            panoCheckBox.checked = false;
        }
        else {
            videoCheckBox.checked = false;
            panoCheckBox.checked = true;
        }
    }

    //刷新分辨率
    function refreshResolution(){
        var saveType = fileOperator.getQMLScreenShotType();
        if(saveType === 0 && panoCheckBox.checked) {
            // 上次保存的是图片类型，切换到全景图片时，分辨率还原成默认
            selectResolutionType = VideoConfig.RESOLUTIONTYPE_4K_IMG;
        }
        else if(saveType === 1 && !panoCheckBox.checked) {
            // 上次保存的是全景图片类型，切换到图片时，分辨率还原成默认
            selectResolutionType = VideoConfig.RESOLUTIONTYPE_1080P;
        }
        else {
            selectResolutionType = fileOperator.getQMLScreenShotResolution(panoCheckBox.checked?true:false);
            // 全景截图已下线 16K(见 ResolutionSettingPanel.qml)，历史保存的 16K 回退到 8K
            if (panoCheckBox.checked && selectResolutionType === VideoConfig.RESOLUTIONTYPE_16K_IMG) {
                selectResolutionType = VideoConfig.RESOLUTIONTYPE_8K_IMG;
            }
        }

        resolution = videoConfig.getImgQmlItemByResolutionType(selectResolutionType);
        if(!panoCheckBox.checked){
            resolutionChooseBtn.text = resolution.name + " - " + resolution.width + "x" + resolution.height;
        }else{
            resolutionChooseBtn.text = resolution.width + "x" + resolution.height;
        }
    }

     // 展示
    function show() {
        screenShotSourcePathForExport = editorManager.getPlayingVideoPath(pop.isPreViewScreenShot);
        formatCombo.currentIndex = 0;
        // 文件名
        fileNameRectangle.setText(jpgFileName);
        // 保存路径
        //filePathChooseText.text = fileOperator.getExportFolder();
        filePathRectangle.contentText = exportSuperPath;
        //导出类型
        refreshScreenShotType();

        // 分辨率
        refreshResolution()
        pop.open();
    }
}
