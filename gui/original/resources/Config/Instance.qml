pragma Singleton
import QtQuick 2.15

QtObject {
    /// 本地素材导入相关
    // 本地列表
    property string key_local_list: "key_local_list"

    /// 排序相关
    // 当前排序选择的索引
    property string key_sort_index: "key_sort_index"
    // 排序（升序/降序）
    property string key_is_ascending: "key_is_ascending"

    // 模式，是大图还是小图
    property string key_mode_grid: "key_mode_grid"

    // 网络请求类型-音乐
    property string request_type_audio: "audio"

    // 网络请求类心-滤镜
    property string request_type_filter: "filter"

    property int audio_wave_track_length: 2

    // 标记点调试开关：true 时标签 svg 切换为 ic_mark_point_2，便于核对标签对齐。仅运行时生效，不持久化
    property bool debugMarkPointUseAltIcon: false

    property string key_screen_shot_save_path: "key_screen_shot_save_path"

    // 水上
    property int waterproof_above: 2
    // 水下
    property int waterproof_under: 3
    // 保护镜
    property int waterproof_stitching: 1
    // 裸镜头
    property int waterproof_bare: 0

    // 文件操控类型
    enum FILE_OPERATE_TYPE {
        // 收藏
        TYPE_OF_FAVORITE,
        // 全选
        TYPE_OF_ALL_SELECT,
        // 移除出列表
        TYPE_OF_REMOVE_FILE_FROM_LIST,
        // 打开文件
        TYPE_OF_OPEN_FILE,
        // 代理文件 关闭
        TYPE_OF_AGENCY_CLOSE,
        // 代理文件 开启
        TYPE_OF_AGENCY_OPEN,
        // 链接
        TYPE_OF_MEDIA_LINK,
        // 硬件删除文件
        TYPE_OF_MEDIA_DEVICE_REMOVE,
        // 硬件下载文件
        TYPE_OF_MEDIA_DEVICE_DOWNLOAD,
        // 下载后的素材
        TYPE_OF_MEDIA_DEVICE_COPIED_OPEN,
        // 发起高光
        TYPE_OF_MEDIA_HIGHLIGHT,
        // 取消高光（删除高光数据）
        TYPE_OF_MEDIA_DEL_HIGHLIGHT,
        // 取消灵感高光分析（取消任务）
        TYPE_OF_MEDIA_CANCEL_HIGHLIGHT,
        // 删除高光片段（高光tab下使用）
        TYPE_OF_DEL_HIGHLIGHT_ITEM,
        // 灵感粗剪
        TYPE_OF_MEDIA_ROUGH_CUT,
        // 上传云相册
        TYPE_OF_UPLOAD_CLOUD_ALBUM,
        // 无
        TYPE_OF_NONE
    }

    // 自定义LUT操作类型
    enum CUSTOM_LUT_OPERATE_TYPE {
        // 重命名
        TYPE_OF_RENAME,
        // 删除
        TYPE_OF_DELETE
    }

    enum DRAFT_OPERATE_TYPE {
        //删除
        TYPE_OF_NONE,
        TYPE_OF_RENAME,
        TYPE_OF_COPY,
        TYPE_OF_DELETE,
        TYPE_OF_PATH
    }

    // 片段上操作类型
    enum FRAGMENT_OPERATE_TYPE {
        // 素材替换
        FRAGMENT_REPALCE,
        // 素材丢失
        FRAGMENT_MEIDA_LOSS,
        // 素材删除
        FRAGMENT_DELETE,
        // 复制关键帧
        KEYFRAME_COPY,
        // 粘贴关键帧
        KEYFRAME_PASTE,
        // 素材导出
        FRAGMENT_COMPOSE,
        //在素材库中显示
        FRAGMENT_SHOW_IN_LIBRARY
    }

        // 片段上操作类型
    enum DEVICE_FILE_TYPE {
        // 创作
        DEVICE_FILE_CREATE,
        // 下载
        DEVICE_FILE_DOWNLOAD,
        // 删除
        DEVICE_FILE_REMOVE,
        // 下载后的素材
        DEVICE_FILE_COPIED_OPEN,
        // 在文件中打开
        DEVICE_FILE_OPEN,
        // 导出为视频文件
        DEVICE_FILE_EXPORT_VIDEO,
        // 灵感高光分析
        DEVICE_FILE_INSPIRATION_HIGHLIGHT,
        // 取消灵感高光分析（取消任务）
        DEVICE_FILE_CANCEL_HIGHLIGHT,
        // 取消高光（删除高光数据）
        DEVICE_FILE_DEL_HIGHLIGHT,
        // 删除高光片段（高光tab下使用）
        DEVICE_FILE_DEL_HIGHLIGHT_ITEM,
        // 灵感粗剪
        DEVICE_FILE_ROUGH_CUT,
        // 上传云相册
        DEVICE_FILE_UPLOAD_CLOUD_ALBUM
    }
    // 流畅模式
    enum AGENCY_TYPE {
        // 超高清
        AGENCY_TYPE_SUPER_HD,
        // 高清
        AGENCY_TYPE_HD,
        // 流畅
        AGENCY_TYPE_SMOOTH, 
        // 打开
        AGENCY_TYPE_OPEN,
        // 关闭
        AGENCY_TYPE_CLOSE
    }
}
