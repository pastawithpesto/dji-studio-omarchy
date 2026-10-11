import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.3
import Qt5Compat.GraphicalEffects

import Controls 1.0
import UIComponent
import Config 1.0

import DeviceMediaCategoryViewModel 1.0

import QtQuick.Dialogs
import Qt.labs.platform
import VideoConfig 1.0
import MediaTypeModel 1.0
import app_qrc 1.0

EnumTabsView {
	id: root
	viewModel: DeviceMediaCategoryViewModel{}
}
