import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Config
import qs.Core
import qs.Widgets

PanelWindow {
    id: picker

    property bool isOpen: false
    signal wallpaperSelected(string path)

    function open() {
        isOpen = true;
        visible = true;
        keyHandler.forceActiveFocus();
        if (wallpaperPaths.length === 0 && folderInput.text !== "")
            scanFolder();
    }

    function close() {
        if (!isOpen) return;
        isOpen = false;
        visible = false;
    }

    function toggle() {
        if (isOpen) close(); else open();
    }

    visible: false
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }

    WlrLayershell.namespace: "mcshell-wallpaper-picker"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    // ── State ────────────────────────────────────────────
    property var wallpaperPaths: []
    property int currentIndex: 0
    property string activeWallpaper: UserSettings.wallpaperPath

    LazyModel {
        id: lazyWall
        sourceModel: picker.wallpaperPaths
        currentIndex: picker.currentIndex
    }

    readonly property real stripWidth: 80
    readonly property real expandedWidth: 650
    readonly property real carouselHeight: 500
    readonly property real stripSpacing: 4
    readonly property int sideCount: 5

    property bool folderFocused: false

    function focusFolder() { folderFocused = true; folderInput.forceActiveFocus(); }
    function focusCarousel() { folderFocused = false; keyHandler.forceActiveFocus(); }

    function navigate(delta) {
        if (wallpaperPaths.length === 0) return;
        currentIndex = Math.max(0, Math.min(wallpaperPaths.length - 1, currentIndex + delta));
    }

    // Calculate the x position of the sliding row so currentIndex is centered
    // Each item is stripWidth except the current which is expandedWidth
    // Center of viewport = carouselArea.width / 2
    // We want the center of the currentIndex item at that point
    function calcRowX() {
        if (wallpaperPaths.length === 0) return 0;
        const visibleLeftCount = Math.min(currentIndex, sideCount);
        const leftWidth = visibleLeftCount * (stripWidth + stripSpacing);
        const centerOffset = expandedWidth / 2;
        return carouselArea.width / 2 - leftWidth - centerOffset;
    }

    Component.onCompleted: {
        if (UserSettings.wallpaperFolder !== "")
            folderInput.text = UserSettings.wallpaperFolder;
        else
            _waitForConfig();
    }

    function _waitForConfig() {
        if (UserSettings.wallpaperFolder !== "")
            folderInput.text = UserSettings.wallpaperFolder;
        else
            Qt.callLater(_waitForConfig);
    }

    // ── Folder scanning ──────────────────────────────────
    property var _scanLines: []

    function scanFolder() {
        const folder = folderInput.text.trim();
        if (folder === "") return;
        UserSettings.wallpaperFolder = folder;
        _scanLines = [];
        scanProc.command = [
            "find", folder, "-maxdepth", "1", "-type", "f",
            "(", "-name", "*.png", "-o", "-name", "*.jpg",
            "-o", "-name", "*.jpeg",
            "-o", "-name", "*.bmp", ")"
        ];
        scanProc.running = true;
    }

    SafeProcess {
        id: scanProc
        failMessage: "wallpaper scan failed — check folder path"
        onRead: data => { picker._scanLines.push(data.trim()); }
        onFinished: {
            const sorted = picker._scanLines.slice().sort();
            picker.wallpaperPaths = sorted;
            picker._scanLines = [];
            picker.currentIndex = 0;
            for (let i = 0; i < sorted.length; i++) {
                if (sorted[i] === picker.activeWallpaper) {
                    picker.currentIndex = i;
                    break;
                }
            }
        }
    }

    // ── Keyboard ─────────────────────────────────────────
    Item {
        id: keyHandler
        anchors.fill: parent
        focus: picker.visible

        Keys.onPressed: event => {
            switch (event.key) {
            case Qt.Key_Escape: picker.close(); event.accepted = true; break;
            case Qt.Key_Left: picker.navigate(-1); event.accepted = true; break;
            case Qt.Key_Right: picker.navigate(1); event.accepted = true; break;
            case Qt.Key_Tab: picker.focusFolder(); event.accepted = true; break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
                if (picker.wallpaperPaths.length > 0) {
                    const path = picker.wallpaperPaths[picker.currentIndex];
                    picker.activeWallpaper = path;
                    picker.wallpaperSelected(path);
                }
                event.accepted = true;
                break;
            }
        }
        onActiveFocusChanged: { if (activeFocus) picker.folderFocused = false; }
    }

    // ── UI ───────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Theme.backdrop
        MouseArea { anchors.fill: parent; onClicked: picker.close() }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 40
        spacing: 0

        Item { Layout.fillHeight: true }

        // ── Folder bar ──────────────────────────────────
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Math.min(600, parent.width - 80)
            Layout.preferredHeight: 40
            Layout.bottomMargin: 16
            radius: 8
            color: Theme.bg
            border.width: 1
            border.color: picker.folderFocused ? Theme.accent : Theme.border
            Behavior on border.color { ColorAnimation { duration: Theme.animNormal } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8

                Text {
                    text: Theme.iconFolder
                    font.family: Theme.iconFont
                    font.pixelSize: 14
                    color: picker.folderFocused ? Theme.accent : Theme.fgDim
                    Layout.alignment: Qt.AlignVCenter
                    Behavior on color { ColorAnimation { duration: Theme.animNormal } }
                }

                TextInput {
                    id: folderInput
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.fg
                    clip: true
                    selectByMouse: true
                    onAccepted: { picker.scanFolder(); picker.focusCarousel(); }
                    Keys.onEscapePressed: picker.close()
                    Keys.onTabPressed: picker.focusCarousel()
                    onActiveFocusChanged: { if (activeFocus) picker.folderFocused = true; }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Enter folder path... (Tab to switch)"
                        color: Theme.fgDim
                        font: parent.font
                        visible: !parent.text
                    }
                }

                IconButton {
                    icon: Theme.iconSearch
                    normalColor: Theme.fgDim
                    hoverColor: Theme.accent
                    size: 14
                    onClicked: { picker.scanFolder(); picker.focusCarousel(); }
                }
            }
        }

        // ── Carousel ────────────────────────────────────
        Item {
            id: carouselArea
            Layout.fillWidth: true
            Layout.preferredHeight: picker.carouselHeight
            clip: true

            Text {
                anchors.centerIn: parent
                visible: picker.wallpaperPaths.length === 0
                text: picker.isOpen && folderInput.text !== ""
                      ? "No images found. Press Enter or click search to scan."
                      : "Enter a folder path above to browse wallpapers."
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                color: Theme.fgDim
            }

            // The sliding row — position animated to keep currentIndex centered
            Row {
                id: slidingRow
                x: picker.calcRowX()
                height: picker.carouselHeight
                spacing: picker.stripSpacing
                visible: picker.wallpaperPaths.length > 0

                Behavior on x {
                    NumberAnimation { duration: Theme.animCarousel; easing.type: Easing.OutCubic }
                }

                Repeater {
                    model: lazyWall.count

                    delegate: Item {
                        id: strip
                        required property int index

                        readonly property string wallPath: picker.wallpaperPaths[index] ?? ""
                        readonly property bool isCurrent: index === picker.currentIndex
                        readonly property bool isActive: wallPath === picker.activeWallpaper
                        readonly property bool isVisible: Math.abs(index - picker.currentIndex) <= picker.sideCount
                        readonly property string fileName: {
                            const parts = wallPath.split("/");
                            return parts[parts.length - 1];
                        }

                        width: isVisible ? (isCurrent ? picker.expandedWidth : picker.stripWidth) : 0
                        height: picker.carouselHeight
                        clip: true
                        opacity: isVisible ? 1.0 : 0.0

                        Behavior on opacity {
                            NumberAnimation { duration: Theme.animSmooth; easing.type: Easing.OutCubic }
                        }

                        Behavior on width {
                            NumberAnimation { duration: Theme.animCarousel; easing.type: Easing.OutCubic }
                        }

                        // Only load image if within visible range
                        Rectangle {
                            anchors.fill: parent
                            radius: strip.isCurrent ? 12 : 8
                            color: Theme.bgSolid
                            clip: true
                            border.width: strip.isActive ? 2 : 0
                            border.color: Theme.accent

                            Behavior on radius {
                                NumberAnimation { duration: Theme.animCarousel; easing.type: Easing.OutCubic }
                            }

                            Image {
                                anchors.fill: parent
                                // Only load if within range — lazy loading
                                source: strip.isVisible ? "file://" + strip.wallPath : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                smooth: true
                                sourceSize.height: picker.carouselHeight
                            }

                            // Filename gradient
                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 60
                                opacity: strip.isCurrent ? 1.0 : 0.0
                                Behavior on opacity { NumberAnimation { duration: Theme.animSmooth } }

                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: "transparent" }
                                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.7) }
                                }

                                Text {
                                    anchors.bottom: parent.bottom
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.margins: 10
                                    text: strip.fileName
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.fg
                                    elide: Text.ElideRight
                                }
                            }

                            // Active checkmark
                            Rectangle {
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: 8
                                width: 28
                                height: 28
                                radius: 14
                                color: Theme.accent
                                visible: strip.isActive

                                Text {
                                    anchors.centerIn: parent
                                    text: Theme.iconCheck
                                    font.family: Theme.iconFont
                                    font.pixelSize: 14
                                    color: Theme.bgSolid
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (strip.isCurrent) {
                                    picker.activeWallpaper = strip.wallPath;
                                    picker.wallpaperSelected(strip.wallPath);
                                } else {
                                    picker.currentIndex = strip.index;
                                }
                            }
                        }
                    }
                }
            }

            // Navigation arrows
            IconButton {
                anchors.left: parent.left
                anchors.leftMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                icon: Theme.iconArrowLeft
                size: 24
                normalColor: Theme.fgDim
                visible: picker.currentIndex > 0 && picker.wallpaperPaths.length > 0
                onClicked: picker.navigate(-1)
            }

            IconButton {
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                icon: Theme.iconArrowRight
                size: 24
                normalColor: Theme.fgDim
                visible: picker.currentIndex < picker.wallpaperPaths.length - 1 && picker.wallpaperPaths.length > 0
                onClicked: picker.navigate(1)
            }
        }

        // ── Footer ──────────────────────────────────────
        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 16
            visible: picker.wallpaperPaths.length > 0
            text: Theme.legend((picker.currentIndex + 1) + " / " + picker.wallpaperPaths.length, Theme.hintNav, "Tab switch", Theme.hintEnter + " apply", Theme.hintClose)
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.fgDim
        }

        Item { Layout.fillHeight: true }
    }
}
