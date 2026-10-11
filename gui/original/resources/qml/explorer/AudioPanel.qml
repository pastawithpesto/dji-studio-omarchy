import QtQuick 2.15
import Config 1.0
import Controls 1.0
import Qt5Compat.GraphicalEffects
import AudioCategoryListModel 1.0
import AudioListModel 1.0
import QtQuick.Controls
import app_qrc 1.0
import QtQuick.Dialogs
import UsedFunctionManager 1.0
import ProjectSettingsInfo 1.0

/**
 * @author robert.guo
 * @desc 音乐详情列表面板
 * @create_date 2024-05-07
 */
Item {
    // 分类数据
    property AudioCategoryListModel categoryModel: null
    // 当前音乐列表展示数据
    property AudioListModel allAudioModels: categoryModel.audioListModel

    property string categoryName: allAudioModels.categoryName
    property int nowIndex:-1
    // 音乐选中的片段的本地文件路径
    property string aduioSelectedPath: ""
    property var importedMusicPaths: []
    // 全景后缀（osv/xtv）跟随白牌切换，扩展名/过滤器统一在 AudioListModel 维护
    readonly property var audioExtensions: allAudioModels ? allAudioModels.audioExtensions() : []
    readonly property var audioNameFilters: allAudioModels ? allAudioModels.audioNameFilters() : []
    onAduioSelectedPathChanged: {
        globalSignal.audioPlayerSelected(aduioSelectedPath);
    }
    onCategoryNameChanged: {
        if (contentLoader.item && contentLoader.item.hasOwnProperty("positionViewAtBeginning")) {
            contentLoader.item.positionViewAtBeginning();
        }
    }
    function handleDrop(drop, allowedExtensions, showToast, waitingPopup, allAudioModels) {
        drop.accept();
        if (drop.hasUrls) {
            var validUrls = [];
            for (var i = 0; i < drop.urls.length; i++) {
                var url = drop.urls[i].toString();
                var extension = url.substring(url.lastIndexOf(".")).toLowerCase();
                if (allowedExtensions.indexOf(extension) !== -1) {
                    validUrls.push(drop.urls[i]);
                } else {
                    showToast("pccut_music_audio_format_fail");
                }
            }
            if (validUrls.length > 0) {
                waitingPopup.open();
                allAudioModels.importAudios(validUrls);
            }
        }
    }
    WaitingPopup {
        id: waitingPopup
        loadingText: qsTr("pccut_music_audio_extracting")
        // 添加计时器
        Timer {
            id: timeoutTimer
            interval: 60000 // 60秒
            onTriggered: {
                waitingPopup.loadingText = qsTr("pccut_music_audio_timeout")
            }
        }

        onOpened: timeoutTimer.start() // 弹窗打开时启动计时
        onClosed: timeoutTimer.stop()  // 弹窗关闭时停止计时
    }

    // 监听点击背景 (为了做取消选中)
    Item {
        id: bgView
        visible: aduioSelectedPath.length > 0
        parent: UiUtils.getTopParent(audiomaterialTabView)
        anchors {
            fill: parent
            leftMargin: 5
            rightMargin: 5
            topMargin: 34
            bottomMargin: 5
        }
        PointHandler {
             onGrabChanged: (transition, eventPointValue) => {
                if (eventPointValue.timeHeld !== 0) {
                    return;
                }
                eventPointValue.accepted = false;
                var mousePoint = eventPointValue.position;
                // audiomaterialTabView 是 SplitView 内容区，不含上方的 TabBar
                // 往上取三级拿到 MaterialPanel 根节点，覆盖 TabBar + 内容区整体
                var panelRoot = audiomaterialTabView.parent.parent.parent;
                var panelPoint = bgView.mapToItem(panelRoot, mousePoint);
                if (!panelRoot.contains(panelPoint)) {
                    stopAudioPlayer();
                }
            }
        }
    }

    Connections {
        target: globalSignal
        function onRefreshMaterialView() {
            allAudioModels.refresh();
        }
        // 轨道视频选中，这里就取消选中
        function onVideoSelected(fragment) {
            if (!CommonUtils.isNull(fragment)) {
                stopAudioPlayer();
            }
        }
    }
    Connections {
        target: allAudioModels
        function onNetworkError() {
            emptyPanel.visible = true;
        }
        function onCountChanged(count) {
            if (count > 0) {
                emptyPanel.visible = false;
            }
        }

        function onDownloadComplete(path, albumPath, songName, audioId) {
            // 防止不展示音乐tab的时候播放音乐
            if (!visible) {
                return;
            }
            preparePlayAudio(path, albumPath, songName, audioId);
            // 下载完成后自动播放预览，与点击已下载音乐一致
            if (audioPlayerPanel.isPlayAble) {
                audioPlayerPanel.seek(0);
                audioPlayerPanel.play();
            }
            eventTracker.trackEvent("pccut_music_preview", {"music_code": audioId})
        }

        function onRetriveAudioComplete(){
            waitingPopup.close()
        }
    }

    DragAudioCover {
        id: draggableRect
        audioListModel: allAudioModels
    }
    function showToast(tips) {
        toast.show(qsTr(tips), 1000);
    }

    function preparePlayAudio(path, albumPath, songName, audioId) {
        if (!audioPlayerPanel.isPlayAble) {
            return;
        }
        audioPlayerPanel.visible = true;
        audioPlayerPanel.path = path;
        audioPlayerPanel.albumPath = albumPath;
        audioPlayerPanel.songName = songName;
        audioPlayerPanel.audioId = audioId;
        audioManager.createMKDrama("qrc:/app_qrc/app_icon.png", audioPlayerPanel.path);
    }

    function stopAudioPlayer() {
        audioPlayerPanel.visible = false;
        audioPlayerPanel.stop();
    }

    Item {
        anchors.fill: parent
        Loader {
            id: contentLoader
            anchors.fill: parent
            sourceComponent: categoryModel.selectIndex != -1 ? listViewComponent : allAudioModels.isEmpty?transparentRectComponent:localListViewComponent
        }
        Component{
            id: listViewComponent
            ListView {
                id: listView
                objectName: actionableItemName.musicContentListView
                anchors.fill: parent
                model: allAudioModels
                clip: true
                spacing: 8
                flickDeceleration: 7000
                onContentYChanged: {
                    if ((contentY + height + 100) > contentHeight) {
                        allAudioModels.fetchNextPage();
                    }
                }
                ScrollBar.vertical: ScrollBar {
                    Component.onCompleted: {
                        contentItem.color = Colors.color_444444;
                    }
                }
                delegate: Item {
                    id: itemRoot
                    // 下载进度
                    property real currentProgress: progress
                    // 是否是播放当前的音乐
                    property bool isCurrentPlay: audioPlayerPanel.visible && audioPlayerPanel.albumPath == imageUrl
                    // 是否在播放中
                    property bool isPlaying: audioPlayerPanel.playing
                    objectName: actionableItemName.delegateItemForMusicContentListView + index

                    width: listView.width - 8 * 2
                    height: 64
                    Rectangle {
                        radius: 8
                        width: parent.width
                        height: parent.height
                        x: 8
                        color: (!mouseArea.isDragAdd && mouseArea.containsMouse) ? Colors.color_353738 : Colors.transparent
                        border.color: isCurrentPlay ? ColorsConfig.color_F22443_4DFFC9 : Colors.transparent
                        border.width: 2
                        Accessible.role: Accessible.Button
                        Accessible.description: "audioedit_musicitem_" + name
                        MouseArea {
                            id: mouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            drag.target: draggableRect
                            // 是否是拖拽添加素材
                            property bool isDragAdd: false
                            // 用户开始点击的位置
                            property point pressedPoint: Qt.point(0, 0)

                            onClicked: {
                                listView.currentIndex = index;
                                // 取消轨道的选中状态
                                globalSignal.cleanTrackSelectState();
                                audioPlayerPanel.isPlayAble = true;
                                if (progress > 1) {
                                    if (!audioPlayerPanel.visible || audioPlayerPanel.songName != name) {
                                        preparePlayAudio(allAudioModels.lookupFinderPath(index), imageUrl, name, audioId);
                                        audioPlayerPanel.seek(0);
                                        audioPlayerPanel.play();
                                        eventTracker.trackEvent("pccut_music_preview", {"music_code": audioId})
                                    } else {
                                        if (itemRoot.isPlaying) {
                                            audioPlayerPanel.pause();
                                        } else {
                                            audioPlayerPanel.play();
                                            eventTracker.trackEvent("pccut_music_preview", {"music_code": audioId})
                                        }
                                    }
                                } else {
                                    stopAudioPlayer();
                                    allAudioModels.download(index);
                                }
                            }
                            onPressedChanged: {
                                if (pressed) {
                                    pressedPoint = Qt.point(mouseX, mouseY);
                                }
                            }
                            onPositionChanged: {
                                var point = mouseArea.mapToItem(addImg, mouseX, mouseY);
                                addImg.containsMouse = addImg.contains(point);
                                if (pressed) {
                                    // 文件不存在禁止拖动
                                    if (progress < 1) {
                                        return;
                                    }
                                    // 增加容错,某些鼠标一点击就有位置移动,鼠标移动多少才认为是拖动
                                    let distance = 2;
                                    if (Math.abs(pressedPoint.x - mouseX) < distance && Math.abs(pressedPoint.y - mouseY) < distance && !isDragAdd) {
                                        return;
                                    }
                                    let point = mapToItem(draggableRect.parent, mouseX, mouseY);
                                    if (!isDragAdd) {
                                        audioPlayerPanel.isPlayAble = false;
                                        editorManager.pause();
                                        stopAudioPlayer();
                                        draggableRect.mediaPath = imageUrl;
                                        draggableRect.index = index;
                                    }
                                    draggableRect.setDragPointMove(point, !isDragAdd);
                                    if (!isDragAdd) {
                                        isDragAdd = true;
                                    }
                                }
                            }
                            onReleased: {
                                if (isDragAdd) {
                                    let point = mapToItem(draggableRect.parent, mouseX, mouseY);
                                    draggableRect.setDragPointRelease(point, false);
                                    isDragAdd = false;
                                }
                            }
                            onCanceled: {
                                if (isDragAdd) {
                                    let point = mapToItem(draggableRect.parent, mouseX, mouseY);
                                    draggableRect.setDragPointRelease(point, true);
                                    isDragAdd = false;
                                }
                            }
                        }
                        LightClipRectangle {
                            id: icon_root
                            width: 56
                            height: 56
                            radius: [6, 6, 6, 6]
                            color: Colors.color_444444
                            anchors {
                                verticalCenter: parent.verticalCenter
                                left: parent.left
                                leftMargin: 4
                            }

                            Image {
                                clip: true
                                anchors.fill: parent
                                source: imageUrl
                                fillMode: Image.PreserveAspectCrop

                                // 播放暂停
                                Rectangle {
                                    visible: itemRoot.isCurrentPlay
                                    color: Colors.color_000000_50
                                    anchors.fill: parent
                                    Image {
                                        width: 16
                                        height: 16
                                        source: itemRoot.isPlaying ? "qrc:/icons/player/ic_pause.svg" : "qrc:/icons/player/ic_play.svg"
                                        sourceSize: Qt.size(width, height)
                                        anchors.centerIn: parent
                                    }
                                }
                            }
                        }
                        Text {
                            id: text
                            text: name
                            font.bold: false
                            font.pixelSize: 12
                            width: parent.width - x - 44
                            wrapMode: Text.WordWrap // 允许在任意位置换行
                            elide: Text.ElideRight // 当文本超出指定宽度时，从右侧省略
                            maximumLineCount: 1
                            color: Colors.color_FFFFFF
                            anchors {
                                left: icon_root.right
                                leftMargin: 8
                                top: parent.top
                                topMargin: 14
                            }
                        }
                        Text {
                            id: time
                            text: UiUtils.formatSeconds(millisecond) // 调用自定义函数来格式化秒数
                            anchors {
                                bottom: parent.bottom
                                left: text.left
                                bottomMargin: 14
                            }

                            font.pixelSize: 11
                            color: Colors.color_959595
                        }

                        Rectangle {
                            id: downloadIcon
                            radius: width / 2
                            width: 20
                            height: 20
                            color: Colors.color_444444_50
                            anchors {
                                right: parent.right
                                rightMargin: 12
                                verticalCenter: parent.verticalCenter
                            }
                            objectName: actionableItemName.downloadForMusic + index
                            Accessible.role: Accessible.Button
                            Accessible.description: progress > 1 ? "audioedit_addmusic" : "audioedit_musicitem_" + name
                            LightToolTip {
                                id: filterAddTip
                                visible: addImg.visible && addImg.containsMouse && mouseArea.containsMouse
                                tip: qsTr("pccut_music_add")
                            }
                            MouseArea {
                                id: addMouseArea
                                anchors.fill: parent
                                onClicked: {
                                    if (progress > 1) {
                                        stopAudioPlayer();
                                        // 防止下载完成后自动播放
                                        audioPlayerPanel.isPlayAble = false;
                                        allAudioModels.addAudioClick(allAudioModels.lookupFinderPath(index));
                                        var projectId = draftManager.activeProjectEnvId();
                                        UsedFunctionManager.addFunction(projectId,UsedFunctionManager.EditorFunctionType.MUSIC);
                                        eventTracker.trackEvent("pccut_music_add", {"use_method": "add_icon", "music_code": audioId})
                                    } else {
                                        stopAudioPlayer();
                                        allAudioModels.download(index);
                                    }
                                }
                            }
                        }

                        Image {
                            id: download_state_img
                            width: 16
                            height: 16
                            anchors.centerIn: downloadIcon
                            source: "qrc:/icons/download_need.svg"
                            visible: currentProgress < 0
                            sourceSize: Qt.size(width, height)

                            LightToolTip {
                                id: downloadTip
                                visible: download_state_img.visible && addImg.containsMouse && mouseArea.containsMouse
                                tip: qsTr("pccut_music_download")
                            }
                        }

                        Image {
                            id: addImg
                            property bool containsMouse: false
                            property bool showAdd: !mouseArea.isDragAdd && (mouseArea.containsMouse || itemRoot.isCurrentPlay)
                            source: showAdd ? "qrc:/app_qrc/icons/filter_add.svg" : "qrc:/icons/filter_add_white.svg"
                            visible: currentProgress >= 1
                            anchors.centerIn: downloadIcon
                            sourceSize: Qt.size(20, 20)
                        }

                        Image {
                            id: rotatingImage
                            width: 16
                            height: 16
                            source: "qrc:/icons/ic_download_loading.png"
                            anchors.centerIn: downloadIcon
                            visible: currentProgress >= 0 && currentProgress < 1
                            smooth: true
                            RotationAnimation on rotation {
                                loops: Animation.Infinite
                                running: rotatingImage.visible && lightWindow.active
                                from: 0
                                to: 360
                                duration: 1000 // 持续时间为1秒
                            }
                        }
                    }
                }
                header: Item {
                    height: categoryName.length > 0 ? 45 : 0
                    Text {
                        text: categoryName
                        font.pixelSize: 12
                        color: Colors.color_EEEEEE
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.top: parent.top
                        anchors.topMargin: 16
                    }
                }
                // 添加footer
                footer: Item {
                    id: list_view_footer
                    width: listView.width
                    height: (visible ? 50 : 0) + audioPlayerPanel.height
                    visible: !emptyPanel.visible && !allAudioModels.isEnd && categoryModel.selectIndex != -1
                    Rectangle {
                        width: childrenRect.width
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: 30
                        Image {
                            id: footer_load_icon
                            width: 16
                            height: 16
                            source: "qrc:/icons/ic_download_loading.png"
                            anchors.verticalCenter: parent.verticalCenter
                            smooth: true
                            ColorOverlay {
                                anchors.fill: footer_load_icon
                                source: footer_load_icon
                                color: ColorsConfig.color_F22443_4DFFC9
                            }
                            RotationAnimation on rotation {
                                loops: Animation.Infinite
                                running: list_view_footer.visible
                                from: 0
                                to: 360
                                duration: 1000 // 持续时间为1秒
                            }
                        }

                        Text {
                            text: qsTr("pccut_media_loading")
                            anchors {
                                left: footer_load_icon.right
                                leftMargin: 6
                                verticalCenter: parent.verticalCenter
                            }
                            font.pixelSize: 12
                            color: ColorsConfig.color_F22443_4DFFC9
                        }
                    }
                }
            }
        }
        Component {
            id: transparentRectComponent
            Item {  // 新增容器
                anchors.fill: parent  // 填满 Loader
                        // 监听拖拽事件
                DropArea {
                    enabled: lightWindow.topPopupCount <= 0
                    anchors.fill: parent
                    onDropped: (drop) => {
                        handleDrop(
                            drop,
                            audioExtensions,
                            showToast,
                            waitingPopup,
                            allAudioModels
                        );
                    }
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 180
                    height: descText.y + descText.height + 27
                    radius: 8                
                    color: emptyMouse.containsMouse ? Colors.color_FFFFFF_10 : Colors.color_2F3032
                    border {
                        width: 1
                        color: Colors.color_454649
                    }
                    MouseArea {
                        id: emptyMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            importMusicDialog.open()
                        }
                    }
                    // 44x44图标
                    Image {
                        id: icon
                        anchors {
                            horizontalCenter: parent.horizontalCenter
                            top: parent.top
                            topMargin: 43
                        }
                        width: 44
                        height: 44
                        source: "qrc:/icons/ic_music_import.svg"
                    }

                    // "提取音频"文字
                    Text {
                        id: titleText
                        text: qsTr("pccut_music_audio_audio")
                        anchors {
                            horizontalCenter: parent.horizontalCenter
                            top: icon.bottom
                            topMargin: 12
                        }
                        width: 123
                        font.pixelSize: 12
                        color: Colors.color_EEEEEE
                        horizontalAlignment: Text.AlignHCenter
                    }

                    // 描述文字
                    Text {
                        id: descText
                        text: qsTr("pccut_music_audio_description")
                        anchors {
                            horizontalCenter: parent.horizontalCenter
                            top: titleText.bottom
                            topMargin: 8
                        }
                        width: 123
                        font.pixelSize: 11
                        color: Colors.color_999999
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
        Component{
            id: localListViewComponent
            ListView {
                id: localListView
                anchors.fill: parent
                model: allAudioModels
                clip: true
                spacing: 8
                flickDeceleration: 7000
                onContentYChanged: {
                    if ((contentY + height + 100) > contentHeight) {
                        //allAudioModels.fetchNextPage();
                    }
                }
                ScrollBar.vertical: ScrollBar {
                    Component.onCompleted: {
                        contentItem.color = Colors.color_444444;
                    }
                }
                    /**
                * @desc 打开音频操作弹框
                *
                * @x 弹框显示的x坐标
                * @y 弹框显示的y坐标
                * @operateFileIndex 操作文件索引
                * @return 无
                */
                function openPopup(x, y) {
                    stopAudioPlayer()
                    audioOperatePopup.x = x;
                    audioOperatePopup.y = y;
                    audioOperatePopup.showPop();
                }
                DropArea {
                    enabled: lightWindow.topPopupCount <= 0
                    anchors.fill: parent
                    onDropped: (drop) => {
                        handleDrop(
                            drop,
                            audioExtensions,
                            showToast,
                            waitingPopup,
                            allAudioModels
                        );
                    }
                }
                delegate: Item {
                    id: itemRoot
                    // 下载进度
                    property real currentProgress: progress
                    // 是否是播放当前的音乐
                    property bool isCurrentPlay: audioPlayerPanel.visible && audioPlayerPanel.songName == name
                    // 是否在播放中
                    property bool isPlaying: audioPlayerPanel.playing

                    width: localListView.width - 8 * 2
                    height: 64
                    Rectangle {
                        radius: 8
                        width: parent.width
                        height: parent.height
                        x: 8
                        color: (!mouseArea.isDragAdd && mouseArea.containsMouse) ? Colors.color_353738 : Colors.transparent
                        border.color: (localListView.currentIndex == index && isCurrentPlay)? ColorsConfig.color_F22443_4DFFC9 : Colors.transparent
                        border.width: 2
                        Accessible.role: Accessible.Button
                        Accessible.description: "audioedit_musicitem_" + name
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.RightButton
                            onClicked: {
                                localListView.currentIndex = index
                                var newPoint = mouseArea.mapToItem(audioOperatePopup.parent, mouseX, mouseY);
                                audioOperatePopup.showPoint = mouseArea.mapToItem(mainPanel, mouseX, mouseY);
                                audioOperatePopup.index = allAudioModels.getModelIndex(index);
                                openPopup(newPoint.x, newPoint.y);
                            }
                            onPressedChanged: {
                                logger.d("[MediaCover] right pressed " + pressed);
                            }
                        }
                        MouseArea {
                            id: mouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton
                            drag.target: draggableRect
                            // 是否是拖拽添加素材
                            property bool isDragAdd: false
                            // 用户开始点击的位置
                            property point pressedPoint: Qt.point(0, 0)

                            onClicked: {
                                localListView.currentIndex = index;
                                // 取消轨道的选中状态
                                globalSignal.cleanTrackSelectState();
                                if(!isExist){
                                    showToast("pccut_music_audio_not_found")
                                    return;
                                }
                                audioPlayerPanel.isPlayAble = true;
                                if (!audioPlayerPanel.visible || audioPlayerPanel.songName != name) {
                                    preparePlayAudio(allAudioModels.lookupFinderPath(index), "qrc:/icons/ic_music_retrive.svg", name, audioId);
                                    audioPlayerPanel.seek(0);
                                    audioPlayerPanel.play();
                                    eventTracker.trackEvent("pccut_music_preview", {"music_code": audioId})
                                } else {
                                    if (itemRoot.isPlaying) {
                                        audioPlayerPanel.pause();
                                    } else {
                                        audioPlayerPanel.play();
                                        eventTracker.trackEvent("pccut_music_preview", {"music_code": audioId})
                                    }
                                }
                            }
                            onPressedChanged: {
                                if(!isExist){
                                    showToast("pccut_music_audio_not_found")
                                    return;
                                }
                                if (pressed) {
                                    pressedPoint = Qt.point(mouseX, mouseY);
                                }
                            }
                            onPositionChanged: {
                                if(!isExist){
                                    return;
                                }
                                var point = mouseArea.mapToItem(addImg, mouseX, mouseY);
                                addImg.containsMouse = addImg.contains(point);
                                if (pressed) {
                                    // 增加容错,某些鼠标一点击就有位置移动,鼠标移动多少才认为是拖动
                                    let distance = 2;
                                    if (Math.abs(pressedPoint.x - mouseX) < distance && Math.abs(pressedPoint.y - mouseY) < distance && !isDragAdd) {
                                        return;
                                    }
                                    let point = mapToItem(draggableRect.parent, mouseX, mouseY);
                                    if (!isDragAdd) {
                                        audioPlayerPanel.isPlayAble = false;
                                        editorManager.pause();
                                        stopAudioPlayer();
                                        draggableRect.mediaPath = "qrc:/icons/ic_music_retrive.svg";
                                        draggableRect.index = index;
                                    }
                                    draggableRect.setDragPointMove(point, !isDragAdd);
                                    if (!isDragAdd) {
                                        isDragAdd = true;
                                    }
                                }
                            }
                            onReleased: {
                                if(!isExist){
                                    return;
                                }
                                if (isDragAdd) {
                                    let point = mapToItem(draggableRect.parent, mouseX, mouseY);
                                    draggableRect.setDragPointRelease(point, false);
                                    isDragAdd = false;
                                }
                            }
                            onCanceled: {
                                if(!isExist){
                                    return;
                                }
                                if (isDragAdd) {
                                    let point = mapToItem(draggableRect.parent, mouseX, mouseY);
                                    draggableRect.setDragPointRelease(point, true);
                                    isDragAdd = false;
                                }
                            }
                        }
                        LightClipRectangle {
                            id: icon_root
                            width: 56
                            height: 56
                            radius: [6, 6, 6, 6]
                            color: Colors.color_444444
                            anchors {
                                verticalCenter: parent.verticalCenter
                                left: parent.left
                                leftMargin: 4
                            }

                            Image {
                                clip: true
                                anchors.fill: parent
                                source: "qrc:/icons/ic_music_retrive.svg"
                                fillMode: Image.PreserveAspectCrop

                                // 播放暂停
                                Rectangle {
                                    visible: itemRoot.isCurrentPlay
                                    color: Colors.color_000000_50
                                    anchors.fill: parent
                                    Image {
                                        width: 16
                                        height: 16
                                        source: itemRoot.isPlaying ? "qrc:/icons/player/ic_pause.svg" : "qrc:/icons/player/ic_play.svg"
                                        sourceSize: Qt.size(width, height)
                                        anchors.centerIn: parent
                                    }
                                }
                            }
                        }
                        Text {
                            id: text
                            text: name
                            font.bold: false
                            font.pixelSize: 12
                            width: parent.width - x - 44
                            wrapMode: Text.WordWrap // 允许在任意位置换行
                            elide: Text.ElideRight // 当文本超出指定宽度时，从右侧省略
                            maximumLineCount: 1
                            color: Colors.color_FFFFFF
                            anchors {
                                left: icon_root.right
                                leftMargin: 8
                                top: parent.top
                                topMargin: 14
                            }
                        }
                        Text {
                            id: time
                            text: UiUtils.formatSeconds(millisecond) // 调用自定义函数来格式化秒数
                            anchors {
                                bottom: parent.bottom
                                left: text.left
                                bottomMargin: 14
                            }

                            font.pixelSize: 11
                            color: Colors.color_959595
                        }

                        Rectangle {
                            id: downloadIcon
                            radius: width / 2
                            width: 20
                            height: 20
                            color: Colors.color_444444_50
                            anchors {
                                right: parent.right
                                rightMargin: 12
                                verticalCenter: parent.verticalCenter
                            }
                            Accessible.role: Accessible.Button
                            Accessible.description: "audioedit_addmusic"
                            LightToolTip {
                                id: filterAddTip
                                visible: addImg.visible && addImg.containsMouse && mouseArea.containsMouse
                                tip: qsTr("pccut_music_add")
                            }
                            MouseArea {
                                id: addMouseArea
                                anchors.fill: parent
                                onClicked: {
                                    stopAudioPlayer();
                                    // 防止下载完成后自动播放
                                    audioPlayerPanel.isPlayAble = false;
                                    allAudioModels.addAudioClick(allAudioModels.lookupFinderPath(index));
                                    var projectId = draftManager.activeProjectEnvId();
                                    UsedFunctionManager.addFunction(projectId,UsedFunctionManager.EditorFunctionType.MUSIC);
                                    eventTracker.trackEvent("pccut_music_add", {"use_method": "add_icon", "music_code": audioId})
                                }
                            }
                        }
                        Image {
                            id: addImg
                            property bool containsMouse: false
                            property bool showAdd: !mouseArea.isDragAdd && (mouseArea.containsMouse || itemRoot.isCurrentPlay)
                            source: showAdd ? "qrc:/app_qrc/icons/filter_add.svg" : "qrc:/icons/filter_add_white.svg"
                            visible: true
                            anchors.centerIn: downloadIcon
                            sourceSize: Qt.size(20, 20)
                        }
                    }
                }
                header: Item {
                    width: parent.width
                    height: 52
                    Rectangle {
                        width: 16 + 8 + 12 + importText.width + 2
                        height: 24
                        color: importMouseArea.containsMouse ? ColorsConfig.color_brand_20 :  ColorsConfig.color_brand_10
                        anchors.top: parent.top
                        anchors.topMargin:16
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        radius: 4
                        Row {
                            spacing: 2
                            anchors.centerIn: parent
                            leftPadding: 8 
                            rightPadding: 12
                            Item {
                                width: 16
                                height: 16
                                Image {
                                    id: retriveBtn
                                    source: "qrc:/icons/ic_import_little.svg"
                                    anchors.verticalCenter: parent.verticalCenter
                                    sourceSize: Qt.size(16, 16)
                                }
                                ColorOverlay {
                                    anchors.fill: retriveBtn
                                    source : retriveBtn
                                    color: ColorsConfig.color_F22443_4DFFC9
                                }
                            }

                            Text {
                                id: importText
                                text: qsTr("pccut_music_audio_audio")
                                font.pixelSize: 12
                                color:  ColorsConfig.color_brand 
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        MouseArea {
                            id: importMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                importMusicDialog.open()
                                localListView.positionViewAtBeginning();
                            }
                        }
                    }
                }
                footer: Item {
                    id: local_list_view_footer
                    width: localListView.width
                    // height: (visible ? 50 : 0) + audioPlayerPanel.height
                    // visible: !emptyPanel.visible && !allAudioModels.isEnd && categoryModel.selectIndex != -1
                    height: audioPlayerPanel.height
                    visible: true
                }
            }
        }

        AudioPlayerPanel {
            id: audioPlayerPanel
            property bool isPlayAble: false
            anchors.bottom: parent.bottom
            visible: false
            width: parent.width
            height: visible ? 74 : 0
            anchors {
                left: parent.left
                right: parent.right
            }
            onPathChanged: {
                if (visible) {
                    aduioSelectedPath = path;
                } else {
                    aduioSelectedPath = "";
                }
            }
            onVisibleChanged: {
                if (visible) {
                    aduioSelectedPath = path;
                } else {
                    aduioSelectedPath = "";
                }
            }
            Connections {
                function onDrameNoCreated() {
                    showToast();
                }
            }
        }

        LightToast {
            id: toast
            anchors.centerIn: parent
        }
    }

    FileDialog {
        id: importMusicDialog
        fileMode: FileDialog.OpenFiles
        nameFilters: audioNameFilters
        onAccepted: {
            waitingPopup.open()
            allAudioModels.importAudios(currentFiles)
        }
    }
    LocalAudioOperatePopup {
        id: audioOperatePopup
        property bool isClicked: false
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        onClickType: (modeType) => {
            switch (modeType) {
                case Instance.FILE_OPERATE_TYPE.TYPE_OF_REMOVE_FILE_FROM_LIST:
                    // 从文件列表移除
                    // 正在使用，需要弹框提示用户
                    if (allAudioModels.isUsedInTrackForSelectedPaths(index)) {
                        audioOperateRemoveAlert.index = index;
                        audioOperateRemoveAlert.open();
                    } else {
                        allAudioModels.removeAudio(index);
                        stopAudioPlayer()
                    }
                    break;
                default:
                    break;
            }
            isClicked = true
        }
        onClosed: {
            isClicked = false
        }
    }

    // 当音频添加到轨道上，在删除、移除时的弹框
    ConfirmPopup {
        id: audioOperateRemoveAlert
        property var index:null
        title: qsTr("pccut_media_remove_title")
        text: qsTr("pccut_media_remove_add_tips")
        leftButtonText: qsTr("pccut_draft_delete_popup_cancel")

        rightButtonText: qsTr("pccut_records_confirm_delete_yes")

        onRightButtonClicked: {
            allAudioModels.removeAudio(index,true);
            stopAudioPlayer();
        }
    }

    EmptyPanel {
        id: emptyPanel
        width: parent.width
        height: parent.height
        anchors.centerIn: parent
        no_network_mode: true
        network_request_type: Instance.request_type_audio
        visible: false
        onClick: {
            if (categoryName.length > 1) {
                allAudioModels.fetchNextPage();
            } else {
                categoryModel.fetchData();
            }
        }
    }
}
