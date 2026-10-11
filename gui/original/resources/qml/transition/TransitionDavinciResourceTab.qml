import QtQuick 2.15
import Config 1.0
import Controls 1.0
import Qt5Compat.GraphicalEffects
import QtQuick.Controls
import app_qrc 1.0
import QtQuick.Dialogs
import TransitionDavinciViewModel 1.0

/**
 * @author hugo.li
 * @desc 转场资源上云资源面板
 * @create_date 2025-11-14
 */
Item{
	id: davinciTabItem
	property double lastTime : 0.0

	function cancelSelect(){
		transitionMaterialModel.select("")
		transitionManager.stopTransitionPreview()
	}

	// 监听点击背景 (为了做取消选中)
	Item {
		id: bgView
		visible: davinciTabItem.visible
		parent: UiUtils.getTopParent(davinciTabItem)
		anchors.fill: parent
		PointHandler {
			onGrabChanged: (transition, point) => {
				point.accepted = false;
				//确保同一物理操作（无论触摸还是鼠标）在短时间内只触发一次
				if (Date.now() - lastTime < 200) {
					return;
				}
				if (point.timeHeld !== 0) {
					return;
				}
				lastTime = Date.now();

				var mousePoint = point.position;
				var clickPoint;

				var needContinue = true;
				clickPoint = bgView.mapToItem(playerPanel, mousePoint);
				// 点击了播放器区域
				if (playerPanel.contains(clickPoint)) {
					needContinue = false;
				}
				if (needContinue) {
					clickPoint = bgView.mapToItem(davinciTabItem, mousePoint);
					if (!davinciTabItem.contains(clickPoint)) {
					   console.log("clicked this lay")

					   cancelSelect()
					}
				}
			}
		}
	}

	// 分类中的取消选中
	MouseArea{
		anchors.fill: parent
		onClicked: {
			cancelSelect()
		}
	}

	// 素材显示分类列表
	ListView {
		id: resourceListView
		// 这里设置宽高、clip都是为了能给mousarea腾出位置做取消选中
		width: parent.width

		//取最小，这样能保证滚动和取消选择的效果
		height:Math.min(resourceListView.contentHeight,davinciTabItem.height)

		// 可以观测界面的四倍，防止滚动的时候突然加载，导致滚动条卡顿引起的滚动效果不流畅问题
		cacheBuffer:  davinciTabItem.height* 4
		property int categoryIndex: transitionMaterialModel.cateogrysModel.selectIndex
		property int currentState:0	// 0 代表默认状态
		// highlightRangeMode:ListView.ApplyRange
		model:transitionMaterialModel.cateogrysModel

		function getCurrentIndex(contentY,height) {
			// console.log(contentY,height,resourceListView.contentHeight)
			if(contentY <= 0 ) return 0
			if(contentY >= resourceListView.contentHeight - height) return resourceListView.count-1
			return  indexAt(0,contentY+height/2)
		}
		boundsBehavior:Flickable.StopAtBounds

		onContentYChanged:{
			if(currentState === 0){
				currentState = 1
			}

			if(currentState === 2){
				return
			}
			// 判断当前所对应的位置
			var currentIndex =getCurrentIndex(contentY,height)
			// console.log(currentIndex)
			// 两个中间会显示-1
			if(currentIndex < 0){
				if(currentState===1){
					currentState=0
				}
				return
			}
			if(categoryIndex!==currentIndex){
				// console.log("change current index:",currentIndex)
				transitionMaterialModel.cateogrysModel.selectIndex = currentIndex
			}

			if(currentState===1){
				currentState=0
			}
		}
		header: Item {
			height: 0
		}
		footer: Item {
			height: 16
		}
		spacing: 8
		delegate: resourceListDelegate

		ScrollBar.vertical: ScrollBar {
			id:scrollBar
			policy: ScrollBar.AsNeeded
			Component.onCompleted: {
				contentItem.color = Colors.color_444444
			}
		}

		onCategoryIndexChanged: {
			if(currentState === 0){
				currentState = 2
			}

			if(currentState === 1){
				return
			}

			if(categoryIndex >= 0
					&& categoryIndex<resourceListView.count){
				resourceListView.positionViewAtIndex(categoryIndex,ListView.Beginning)
			}
			if(currentState === 2){
				currentState = 0
			}
		}
	}

	// 素材分类代理
	Component {
		id: resourceListDelegate
		Item{
			id: containerItem
			height: resourceGridView.contentHeight + categoryTitle.height+24
			width: davinciTabItem.width
			property int mIndex:index

			// 单个分类的素材列表
			TransitionDavinciViewModel{
				id:davinciViewModel
				categorySlug:model.slug
			}

			// 每段的上间距
			Rectangle{
				id:headerRec
				width: parent.width
				height: 16
				color: Colors.transparent
			}

			// 分类名称
			Text {
				id: categoryTitle
				height: 16
				width: 100
				text: model.name
				color: Colors.color_EEEEEE

				font.pixelSize: 12
				anchors{
					top:headerRec.bottom
					left: parent.left
					leftMargin: 12
				}
			}

			// 分类中的取消选中
			MouseArea{
				anchors.fill: parent
				onClicked: {
					cancelSelect()
				}
			}

			// 其中展示某一个分类下的所有资源
			GridView {
				id: resourceGridView
				interactive: false // 禁用所有交互（包括滚动和拖拽）
				focus:true
				anchors{
					top: categoryTitle.bottom
					topMargin: 16
					left: parent.left
					right:parent.right
					leftMargin: 12
				}
				height: parent.height
				width: parent.width
				cellWidth: 80+12
				cellHeight: 100+12
				clip: true

				model:davinciViewModel

				delegate: TransitionMaterialItemView {
					id:itemView
					visible: (typeof model.name !== "undefined")
					resourceName: (typeof model.name !== "undefined") ? model.name : ""
					imageUrl: (typeof model.imageUrl !== "undefined") ? model.imageUrl : "";
					hoverImage: (typeof model.hoverImage !== "undefined") ? model.hoverImage : "";
					resourceSlug:(typeof model.slug !== "undefined") ? model.slug : "";
					currentSelectGrid:davinciViewModel.categorySlug === transitionMaterialModel.currentCategory
					implicitWidth: 80
					implicitHeight: 100
					Connections{
						target: itemView
						function onDownload(index){
							davinciViewModel.download(index)
						}
						function onCollect(index,isCollect){
							davinciViewModel.collect(index,isCollect)
						}
						function onAddTransition(slug){
							transitionMaterialModel.addTransition(slug)
						}
						function onSelectItem(slug){
							transitionMaterialModel.select(davinciViewModel.categorySlug)
						}
						function onPreview(slug){
							transitionMaterialModel.preview(slug)
						}
					}
				}
			}
		}
	}
}


