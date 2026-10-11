import QtQuick 2.15
import QtQuick.Layouts 1.15
import Controls 1.0
import Config 1.0
import CloudAlbumAssetListModel 1.0
import CloudAlbumBenefitViewModel 1.0
import CloudAlbumMediaCategoryViewModel 1.0
import CloudAlbumRecycleBinModel 1.0
import CloudAlbumManager 1.0

Item {
    id: root
    objectName: "cloudAlbumView"

    property bool isLoggedIn: CloudAlbumManager.isLoggedIn
    property bool forceShowBetaView: lightSetting.getBool("debug_force_cloud_album_beta_view", false)
    property bool forceShowGuideStepsView: lightSetting.getBool("debug_force_cloud_album_guide_steps_view", false)
    property bool hasForcedGuideView: forceShowBetaView || forceShowGuideStepsView
    property bool showGuide: isLoggedIn && (hasForcedGuideView || benefitViewModel.showGuide)

    function syncLoginStatePage() {
        if (!isLoggedIn) {
            cloudAlbumStack.currentIndex = 0
            return
        }
        if (hasForcedGuideView) {
            cloudAlbumStack.currentIndex = 1
            return
        }
        if (cloudAlbumStack.currentIndex === 0) {
            cloudAlbumStack.currentIndex = 1
        }
    }

    // 滚动到指定文件名的素材
    function scrollToFileName(fileName) {
        if (!root.isLoggedIn) {
            cloudAlbumStack.currentIndex = 0
            return false
        }
        if (root.hasForcedGuideView) {
            cloudAlbumStack.currentIndex = 1
            return false
        }
        // 确保切到已登录主页
        cloudAlbumStack.currentIndex = 1;
        return loggedInView.scrollToFileName(fileName);
    }

    onIsLoggedInChanged: syncLoginStatePage()
    onForceShowBetaViewChanged: syncLoginStatePage()
    onForceShowGuideStepsViewChanged: syncLoginStatePage()

    // 云相册素材列表数据源
    CloudAlbumAssetListModel {
        id: cloudAlbumAssetModel
        objectName: "cloudAlbumAssetModel"
    }

    // 权益信息
    CloudAlbumBenefitViewModel {
        id: benefitViewModel
        objectName: "cloudAlbumBenefitViewModel"
    }

    CloudAlbumMediaCategoryViewModel {
        id: cloudAlbumMediaCategoryViewModel
        objectName: "cloudAlbumMediaCategoryViewModel"
        highlightEnabled: cloudAlbumFeatureFlags.highlightEnable
    }

    Component.onDestruction: {
        benefitViewModel.stopClaimCheck()
    }

    CloudAlbumToastHost {
        id: cloudAlbumToastHost
        anchors.fill: parent
        visible: root.visible
    }

    Connections {
        target: globalSignal
        function onCloudAlbumDebugRefreshBenefit() {
            root.forceShowBetaView = lightSetting.getBool("debug_force_cloud_album_beta_view", false)
            root.forceShowGuideStepsView = lightSetting.getBool("debug_force_cloud_album_guide_steps_view", false)
            benefitViewModel.refreshQuota()
            benefitViewModel.refreshExpireDate()
        }
    }

    // 账户登录处更新头像时，同步通知云相册权益 ViewModel 更新头像
    Connections {
        target: userLoginViewModel
        function onAvatarPathChanged() {
            benefitViewModel.setAvatarPath(userLoginViewModel.avatarPath)
        }
    }

    // 账户登录处更新头像时，同步通知云相册权益 ViewModel 更新头像
    Connections {
        target: userLoginViewModel
        function onAvatarPathChanged() {
            benefitViewModel.setAvatarPath(userLoginViewModel.avatarPath)
        }
    }

    // 回收站数据源
    CloudAlbumRecycleBinModel {
        id: recycleBinModel
        objectName: "cloudAlbumRecycleBinModel"
    }

    StackLayout {
        id: cloudAlbumStack
        objectName: "cloudAlbumStack"
        anchors.fill: parent
        currentIndex: root.isLoggedIn ? 1 : 0

        // index 0: 未登录
        CloudAlbumNotLoginView {
            objectName: "cloudAlbumNotLoginView"
            onLoginClicked: {
                userLoginViewModel.showLoginPopup()
            }
        }

        // index 1: 已登录主页
        CloudAlbumLoggedInView {
            id: loggedInView
            objectName: "cloudAlbumLoggedInView"
            showGuide: root.showGuide
            forceShowBetaView: root.forceShowBetaView
            forceShowGuideStepsView: root.forceShowGuideStepsView
            benefitViewModel: benefitViewModel
            mediaCategoryViewModel: cloudAlbumMediaCategoryViewModel
            cloudAlbumModel: cloudAlbumAssetModel
            usedStorage: benefitViewModel.usedBytes / Math.pow(CommonUtils.base_file_number, 3)
            totalStorage: benefitViewModel.totalBytes / Math.pow(CommonUtils.base_file_number, 3)
            isBenefitExpired: benefitViewModel.isBenefitExpired
            expireDay: benefitViewModel.expireDay
            expireDeleteMeta: benefitViewModel.expireDeleteMeta
            expireDate: benefitViewModel.expireTimeStr.length > 0
                ? Qt.formatDate(new Date(benefitViewModel.expireTimeStr), "yyyy-MM-dd")
                : ""
            avatarSource: benefitViewModel.avatarPath
            userName: userLoginViewModel.nickname !== "" ? userLoginViewModel.nickname : "User"

            onRecycleBinClicked: {
                cloudAlbumStack.currentIndex = 2;
            }

            Component.onCompleted: {
                if (root.isLoggedIn) {
                    cloudAlbumAssetModel.refresh();
                    benefitViewModel.refreshQuota();
                    benefitViewModel.refreshExpireDate();
                    benefitViewModel.checkShowGuide();
                    benefitViewModel.setAvatarPath(userLoginViewModel.avatarPath);
                }
            }
            onVisibleChanged: {
                if (visible && root.isLoggedIn) {
                    benefitViewModel.refreshQuota();
                    benefitViewModel.refreshExpireDate();
                    benefitViewModel.checkShowGuide();
                    benefitViewModel.setAvatarPath(userLoginViewModel.avatarPath);
                }
            }
        }

        // index 2: 回收站
        CloudAlbumRecycleBinView {
            objectName: "cloudAlbumRecycleBinView"
            recycleBinModel: recycleBinModel

            onBackClicked: {
                cloudAlbumStack.currentIndex = root.isLoggedIn ? 1 : 0;
            }
            onVisibleChanged: {
                if (visible && root.isLoggedIn) {
                    recycleBinModel.refresh();
                }
            }
        }
    }

    // checkShowGuide 异步校验期间显示 loading 遮罩
    LoadingPanelView {
        objectName: "cloudAlbumLoadingPanel"
        anchors.fill: parent
        visible: benefitViewModel.isCheckingGuide
    }
}
