pragma Singleton
import QtQuick 2.15

QtObject {
    // -------  品牌色  -----------
    property color color_F22443: "#F22443"
    property color color_F44C65: "#F44C65"
    property color color_3392FF: "#3392FF"
    property color color_FF0000: "#FF0000"  // 纯红，用于新功能小红点指示器
    property color color_0000FF: "#0000FF"  // 纯蓝，用于色轮蓝色通道输入框下方线条


    // -------  使用颜色，进行颜色设置时尽量使用这一部分的颜色  -----------
    // 新增颜色是添加注释对颜色用途进行说明

    property color color_panorama_panel_gradient_start_color: "#00000000"
    property color color_panorama_panel_gradient_end_color: "#31000000"
    property color color_tk_rect_border: "#00ff00"
    property color color_tk_rect_fill: "#3300ff00"
    property color color_panorama_enter_tk_edit_normal: "#666666"
    property color base_color_main_background: "#262728"
    property color base_corlor_hilight: "#FD5050"
    property color base_corlor_hilight_70: "#B2FD5050"
    property color base_corlor_hilight_50: "#80FD5050"

    // ---------------  区域类  -------------------
    // 标题栏、工具栏等显示在“头”位置的背景色
    property color color_title_area_background: color_2F3032

    // 内容部分区域的背景色，一般和“头”部背景色搭配使用
    property color color_content_area_background: color_1F2021

    // app最底层的背景色
    property color color_deepest_background: color_141414

    // 轨道区域单一轨道背景色
    property color color_track_dock_line_background_normal: color_19191A_40

    // 轨道区域单一轨道选中时背景色
    property color color_track_dock_line_background_selected: color_19191A

    // ---------------  按钮类  -------------------
    // 点击类按钮的普通状态背景色
    property color color_button_background_normal: color_2F3032
    // 点击类按钮的悬停状态背景色
    property color color_button_background_hovered: color_37383A

    // 可选中按钮、页签、导航标签选中态背景色
    property color color_check_button_background_checked: color_2F3032
    // 可选中按钮、页签、导航标签选中态文字色
    property color color_check_button_text_checked: color_EEEEEE
    // 可选中按钮、页签、导航标签未选中态文字色
    property color color_check_button_text_normal: color_999999

    // 轨道工具栏按钮hover背景色
    property color color_track_tool_button_background_hovered: color_454649

    // ---------------  其他  -------------------
    // 轨道时间指示器不可用时颜色
    property color color_track_indicator_disabled: color_454649


    // ---------------  颜色库  -------------------
    property color color_37383A: "#37383A"
    property color color_F22443_10: "#1AF22443"
    property color color_F22443_20: "#33F22443"
    property color color_F22443_50: "#80F22443"

    // 背景色
    property color color_1F2021: "#1F2021"

    // 边框的颜色
    property color color_000000: "#000000"
    property color color_000000_15: Qt.rgba(0, 0, 0, 0.15)
    property color color_000000_20: "#33000000"
    property color color_000000_30: Qt.rgba(0, 0, 0, 0.3)
    property color color_000000_40: Qt.rgba(0, 0, 0, 0.4)
    property color color_000000_60: Qt.rgba(0, 0, 0, 0.6)
    // 黑色 50% 透明
    property color color_000000_50: "#80000000"

    // 滑杆不可视的颜色
    property color color_4D4D4D: "#4D4D4D"
    // 滑杆可视的颜色
    property color color_D8D8D8: "#D8D8D8"
    property color color_D8D8D8_20: "#33D8D8D8"
    // 滑杆 手柄的颜色
    property color color_E8E8E8: "#E8E8E8"

    property color color_191919: "#191919"
    property color color_19191A: "#19191A"
    property color color_19191A_D8: "#19191AD8"
    property color color_19191A_40: "#6619191A"

    property color color_121212: "#121212"
    //透明色
    property color color_transparent: "transparent"
    property color transparent: "transparent"
    property color color_959595: "#959595"
    property color color_FFFFFF: "#FFFFFF"
    property color color_FF5F57: "#FF5F57"
    property color color_FEBC2E: "#FEBC2E"
    property color color_FFFFFF_05: "#0DFFFFFF"
    property color color_FFFFFF_08: "#14FFFFFF"
    property color color_FFFFFF_10: "#19FFFFFF"
    property color color_FFFFFF_15: "#26FFFFFF"
    property color color_FFFFFF_20: "#33FFFFFF"
    property color color_FFFFFF_25: "#40FFFFFF"
    property color color_FFFFFF_30: "#4CFFFFFF"
    property color color_FFFFFF_40: "#66FFFFFF"
    property color color_FFFFFF_45: "#72FFFFFF"
    property color color_FFFFFF_50: "#80FFFFFF"
    property color color_FFFFFF_60: "#99FFFFFF"
    property color color_28C840: "#28C840"
    property color color_262728: "#262728"
    property color color_262728_30: "#4D262728"
    property color color_262728_50: "#80262728"
    property color color_EEEEEE: "#EEEEEE"
    property color color_EEEEEE_30: "#4DEEEEEE"
    property color color_CCCCCC: "#CCCCCC"
    property color color_CCCCCC_10: "#19CCCCCC"
    property color color_333333: "#333333"
    property color color_333333_80: "#CC333333"
    property color color_999999: "#999999"
    property color color_141414: "#141414"
    property color color_141414_30: "#46141414"
    property color color_141414_50: "#80141414"
    property color color_141414_80: "#cc141414"
    property color color_141414_70: "#B3141414"
    property color color_141414_85: "#D9141414"
    property color color_161616: "#161616"
    property color color_666666: "#666666"
    property color color_666666_50: "#80666666"
    property color color_1D1E1F: "#1D1E1F"
    property color color_F6C234: "#F6C234"
    property color color_3B6CDF: "#3B6CDF"
    property color color_26FF31: "#26FF31"
    property color color_E312FF: "#E312FF"
    property color color_FFCC00: "#FFCC00"
    property color color_FFCC00_30: "#AAFFCC00"
    property color color_000000_70: "#B2000000"
    property color color_292B30: "#292B30"
    property color color_808080: "#808080"
    property color color_427ED8: "#427ED8"
    property color color_343434: "#343434"
    property color color_EEEEEE_20: "#33EEEEEE"
    property color color_EEEEEE_50: "#80EEEEEE"
    property color color_444444: "#444444"
    property color color_444444_50: "#80444444"
    property color color_353738: "#353738"
    property color color_41D95D: "#41D95D"
    property color color_303233: "#303233"
    property color color_494848: "#494848"
    property color color_3d3b3b_80: "#803d3b3b"
    property color color_FF6262: "#FF6262"
    property color color_F22443_15: "#26F22443"
    property color color_777777: "#777777"
    property color color_414344: "#414344"
    property color color_4B4B4B: "#4B4B4B"
    property color color_2D2D2D: "#2D2D2D"
    property color color_2F3032: "#2F3032"
    property color color_2F3032_20: "#512F3032"
    property color color_2F3032_00: "#002F3032"
    property color color_2F3032_40: "#662F3032"
    property color color_454649: "#454649"
    property color color_2460B9: "#2460B9"
    property color color_2460B9_15: "#262460B9"
    property color color_78A7EC: "#78A7EC"
    property color color_1C4B91: "#1C4B91"
    property color color_C4D8F7: "#C4D8F7"
    property color color_2E2E2E: "#2E2E2E"
    property color color_143668: "#143668"
    property color color_143668_40: "#66143668"
    property color color_5346C2: "#5346C2"
    property color color_5346C2_15: "#265346C2"
    property color color_9D92F3: "#9D92F3"
    property color color_2E276D: "#2E276D"
    property color color_F2F2F2: "#F2F2F2"

    property color color_32E494: "#32E494"
    property color color_32E494_20: "#3332E494"
    property color color_32E494_60: "#9932E494"
    property color color_3392FF_60: "#993392FF"
    property color color_5BA6F7_60: "#995BA6F7"
    property color color_492C2D: "#492C2D"

    property color color_FF9333: "#FF9333"
    property color color_FF9333_60: "#99FF9333"
    property color color_FFAA5E_60: "#99FFAA5E"

    property color color_414344_100: "#414344"
    property color color_575A5B_100: "#575A5B"

    property color color_5BF7B1: "#5BF7B1"
    property color color_5BF7B1_60: "#995BF7B1"
    property color color_56575B: "#56575B"
    property color color_56575B_50: "#8056575B"

    property color color_252627: "#252627"
    property color color_C61E37: "#C61E37"

    property color color_7A7B80: "#7A7B80"
    property color color_68696D: "#68696D"
    property color color_33000000: "#33000000"
    property color color_80000000: "#80000000"
    property color color_1f2021: "#1f2021"

    property color color_0C213F: "#0C213F"
    property color color_575859: "#575859"
    property color color_262626: "#262626"
    property color color_3498DB: "#3498db"
    property color color_2980B9: "#2980b9"
    property color color_1E1E1E: "#1E1E1E"
    property color color_EEEEEE_15: "#0FEEEEEE"
    property color color_515151: "#515151"
    property color color_373737: "#373737"
    property color color_EBEBEB: "#EBEBEB"

    property color color_B1B1B1: "#B1B1B1"
    property color color_222222: "#222222"
    property color color_202020: "#202020"
    property color color_9F9E9F: "#9F9E9F"
    property color color_3F3E3F: "#3F3E3F"
    property color color_8F8F8F: "#8F8F8F"
    property color color_676767: "#676767"
    property color color_414141: "#414141"
    property color color_009DFF: "#009DFF"
    property color color_9EC0F2_50: "#809EC0F2"
    property color color_9EC0F2_60: "#999EC0F2"
    property color color_353637: "#353637"
    property color color_A24FE2: "#A24FE2"

    // 云相册按钮选中态颜色
    property color color_F6B66B: "#F6B66B"
    property color color_373431: "#373431"
    // 云相册登录按钮渐变色
    property color color_FDD2A3: "#FDD2A3"
    property color color_F1D7C0: "#F1D7C0"
    // 云相册进度条 & 订阅按钮渐变色
    property color color_FC4763: "#FC4763"
    property color color_FFB26D: "#FFB26D"
    property color color_FF8111: "#FF8111"
    property color color_FF7B00: "#FF7B00"
    property color color_FFCEA3: "#FFCEA3"
    property color color_FFC089: "#FFC089"
}
