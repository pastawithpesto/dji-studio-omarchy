import QtQuick 2.15
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import LightRectangle 1.0

/**
 * Created by whiskey.cao on 2024-02-06 .
 * ClassName : LightClipRectangle
 * Description :实现圆角Clip,注意开启了硬件加速，没有clip建议不使用
 * Copyright : ©2024 Light All Rights Reserved.
 */
LightRectangle {
    id:control
    color: "#00000000"
    layer.enabled: true
    layer.effect: OpacityMask{
        maskSource: ShaderEffectSource{
            sourceItem: LightRectangle{
                radius: control.radius
                width: control.width
                height: control.height
            }
        }
    }
}

