pragma Singleton
import QtQuick 2.15

QtObject {
    // -------  studio 颜色配置  -----------
    //studio 主题色,主要是红色
    property color color_brand: "#F22443"
    property color color_brand_10: "#1AF22443" 
    property color color_brand_20: "#33F22443"
    property color color_brand_50: "#80F22443"

    // studio+白牌颜色 根据配置切换
    property color color_FFFFFF_6DFFD3: "#FFFFFF"
    property color color_EEEEEE20_4DFFC920: "#33EEEEEE"
    property color color_666666_4DFFC9: "#666666"
    property color color_FD5050_4DFFC9: "#FD5050"
    property color color_FFFFFF_4DFFC9: "#FFFFFF"

    //弹出操作框
    // 弹出操作框按钮的hover文本色
    property color color_EEEEEE_4DFFC9: "#EEEEEE"
    // 弹出操作框按钮的hover背景色
    property color color_FFFFFF15_4DFFC920: "#26FFFFFF"
    //  #37383A
    property color color_37383A_4DFFC920: "#37383A"

    //主题按钮
    // 按钮normal背景色
    property color color_F22443_4DFFC9: "#F22443"
    // 按钮hover背景色
    property color color_F44C65_6DFFD3: "#F44C65"
    // 按钮press背景色
    property color color_F44C65_4DFFC9: "#F44C65"
    // 按钮文本色
    property color color_FFFFFF_000000: "#FFFFFF"

    //标签文本
    //文本色
    property color color_3392FF_4DFFC9: "#3392FF"

    //下拉框
    //背景颜色
    property color color_68696D_4DFFC920: "#68696D"
    property color color_353738_4DFFC920: "#353738"

    //拖拽轨道视频文字颜色
    property color color_78A7EC_78E5DE: "#78A7EC"
    //视频投影色
    property color color_2460B9_transparent: "#2460B9"
    property color color_2460B915_04585820: "#262460B9"
    //音频文字颜色
    property color color_9D92F3_68AAFC: "#9D92F3"
    //音频投影色
    property color color_5346C2_transparent: "#5346C2"
    property color color_5346C215_0F305840: "#265346C2"

    //轨道片段颜色
    property color color_143668_045858: "#143668"
    property color color_1F2021_000000 : "#1F2021"
    //效果字段背景颜色
    property color color_1C4B91_0E7E7E: "#1C4B91"
    property color color_2460B9_15A4A4: "#2460B9"
    property color color_0C213F_154747: "#0C213F"
    //效果字段文字颜色
    property color color_C4D8F7_CDFFF0: "#C4D8F7"
    property color color_EEEEEE_000000: "#EEEEEE"
    //音频片段背景色
    property color color_2E276D_0F3058: "#2E276D"
    property color color_492C2D_15473C: "#492C2D"
    //文本片段文字颜色
    property color color_95FCEB_95FCEB: "#95FCEB"
    //文本投影色
    property color color_0A9B83_transparent: "#0A9B83"
    property color color_0A9B8315_0A9B8315: "#260A9B83"


    //追踪
    property color color_32E494_4DFFC9: "#32E494"
    property color color_5BF7B160_4DFFC960: "#995BF7B1"
    property color color_32E49460_4DFFC960: "#9932E494"

    // 轨道区域单一轨道背景色
    property color color_track_dock_line_background_normal: "#6619191A"

    // 轨道区域单一轨道选中时背景色
    property color color_track_dock_line_background_selected: "#19191A"

    property color color_2F3032_transparent: "#2F3032"

    property color color_454649_transparent: "#454649"
}
