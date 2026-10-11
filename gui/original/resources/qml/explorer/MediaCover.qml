/**
 * @author: fread.zhang
 * @details: 展示视频的抽帧
 * @date: 2024-09-09 21:23:34
 */
import QtQuick 2.15

Item {
    id: imageBox
    // 显示视频的时间点单位(底层时间片)
    property int imageTime
    // 视频的路径
    property string mediaCachePath
    property string mediaPath
    // 视频分段MD5(上游预算)，拼进 URL 下传给 provider，避免其在 UI 线程重算导致卡死；缺省为空时 provider 回退自算
    property string mediaMd5: ""

    property bool isGridModel : false;
    property string imagePath: mediaPath + ";" + mediaMd5 + ";" + imageTime + ";0;0;1;" + (isGridModel ? "1" : "0")
    property bool needScale: false
    property int retryCount: 0  // 记录当前重试次数
    property int retryMaxCount: 3  // 重试次数限制

    // 定时器的作用: 素材封面长图首次抽帧时，在抽帧速度较慢时，会出现大面积的黑色空位
    // 主要原因时: cache首次从缓存中加载图片时缓存可能为空，主要是因为request异步抽帧第一帧还没有完成
    // 解决方案: 所以间隔一小段时间后再次尝试从缓存中获取, 使用缓存中最佳的抽帧先进行占位，待request中的异步抽帧完成后在进行更新
    Timer {
        id: retryTimer
        interval: 1000 * Math.pow(2, retryCount)  // 重试间隔时间1s→2s→8s
        repeat: false
        onTriggered: {
            if (retryCount < retryMaxCount) {
                forceReload();
                retryCount++
            } else {
                retryTimer.stop()  // 超过3次停止定时器
            }
        }
    }

    function forceReload() {
        var oldPath = imagePath
        cache.source = "" // 清空源路径
        cache.source = "image://track_frame_cache/" + oldPath
    }

    Image {
        id: cache
        anchors.fill: parent
        fillMode: needScale ? Image.PreserveAspectCrop : Image.PreserveAspectFit
        visible: request.status !== Image.Ready
        source: "image://track_frame_cache/" + imageBox.imagePath
        sourceSize: Qt.size(parent.width, parent.height)

        onImplicitHeightChanged: {
            if(implicitHeight < 5){  // 这里来判断provider返回的图片是否有效，没有加载到有效图片时，provider返回一个默认小图
                retryTimer.restart()
            }else{
                retryTimer.stop()
                retryCount = 0
            }
        }
    }

    Image {
        id: request
        anchors.fill: parent
        fillMode: needScale ? Image.PreserveAspectCrop : Image.PreserveAspectFit
        visible: status === Image.Ready
        asynchronous: true
        source: "image://track_frame/" + imageBox.imagePath
        sourceSize: Qt.size(parent.width, parent.height)
    }
}
