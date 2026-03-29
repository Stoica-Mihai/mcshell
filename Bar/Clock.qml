import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Config
import qs.Widgets

Item {
    id: root

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    property date currentDate: new Date()
    property bool popupVisible: calendarPopup.isOpen

    function dismissPopup() {
        calendarPopup.close();
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.currentDate = new Date()
    }

    Text {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.fg
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        font.weight: Font.Medium
        text: root.currentDate.toLocaleDateString(Qt.locale(), "ddd d MMM") +
              "  " +
              root.currentDate.toLocaleTimeString(Qt.locale(), "HH:mm")
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (calendarPopup.isOpen)
                calendarPopup.close();
            else {
                calendarPopup.viewDate = new Date();
                calendarPopup.open();
            }
        }
    }

    AnimatedPopup {
        id: calendarPopup

        property date viewDate: new Date()
        property int viewYear: viewDate.getFullYear()
        property int viewMonth: viewDate.getMonth()

        fullHeight: calContent.implicitHeight + 16
        implicitWidth: 240

        anchor.item: root
        anchor.rect.x: -(implicitWidth / 2 - root.width / 2)
        anchor.rect.y: (Theme.barHeight + root.height) / 2 - 2

        function prevMonth() {
            const d = new Date(viewYear, viewMonth - 1, 1);
            viewDate = d;
        }
        function nextMonth() {
            const d = new Date(viewYear, viewMonth + 1, 1);
            viewDate = d;
        }

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: Theme.bgSolid
            border.width: 1
            border.color: Theme.border

            ColumnLayout {
                id: calContent
                anchors.fill: parent
                anchors.margins: 8
                spacing: 6

                // Month/year header with nav
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        text: "\u25C0"
                        color: prevMouse.containsMouse ? Theme.accent : Theme.fgDim
                        font.pixelSize: 10
                        MouseArea {
                            id: prevMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: calendarPopup.prevMonth()
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: {
                            const d = new Date(calendarPopup.viewYear, calendarPopup.viewMonth, 1);
                            return d.toLocaleDateString(Qt.locale(), "MMMM yyyy");
                        }
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        font.weight: Font.Medium
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: "\u25B6"
                        color: nextMouse.containsMouse ? Theme.accent : Theme.fgDim
                        font.pixelSize: 10
                        MouseArea {
                            id: nextMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: calendarPopup.nextMonth()
                        }
                    }
                }

                // Day-of-week headers
                Grid {
                    Layout.fillWidth: true
                    columns: 7
                    columnSpacing: 0
                    rowSpacing: 2

                    Repeater {
                        model: {
                            const locale = Qt.locale();
                            const names = [];
                            // Monday-first week
                            for (let i = 1; i <= 7; i++) {
                                const d = new Date(2024, 0, i); // 2024-01-01 is Monday
                                names.push(d.toLocaleDateString(locale, "ddd").substring(0, 2));
                            }
                            return names;
                        }

                        Text {
                            required property string modelData
                            width: 32
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            color: Theme.fgDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }
                }

                // Day grid
                Grid {
                    Layout.fillWidth: true
                    columns: 7
                    columnSpacing: 0
                    rowSpacing: 2

                    Repeater {
                        model: {
                            const year = calendarPopup.viewYear;
                            const month = calendarPopup.viewMonth;
                            const firstDay = new Date(year, month, 1);
                            const lastDay = new Date(year, month + 1, 0);

                            // Monday = 0, Sunday = 6
                            let startDow = firstDay.getDay() - 1;
                            if (startDow < 0) startDow = 6;

                            const cells = [];
                            // Previous month padding
                            const prevLast = new Date(year, month, 0).getDate();
                            for (let i = startDow - 1; i >= 0; i--)
                                cells.push({ day: prevLast - i, current: false });
                            // Current month
                            for (let d = 1; d <= lastDay.getDate(); d++)
                                cells.push({ day: d, current: true });
                            // Next month padding
                            while (cells.length < 42)
                                cells.push({ day: cells.length - startDow - lastDay.getDate() + 1, current: false });

                            return cells;
                        }

                        Rectangle {
                            required property var modelData

                            width: 32
                            height: 24
                            radius: 4
                            color: {
                                const now = root.currentDate;
                                if (modelData.current
                                    && modelData.day === now.getDate()
                                    && calendarPopup.viewMonth === now.getMonth()
                                    && calendarPopup.viewYear === now.getFullYear())
                                    return Theme.accent;
                                return "transparent";
                            }

                            Text {
                                anchors.centerIn: parent
                                text: modelData.day
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                color: {
                                    const now = root.currentDate;
                                    const isToday = modelData.current
                                        && modelData.day === now.getDate()
                                        && calendarPopup.viewMonth === now.getMonth()
                                        && calendarPopup.viewYear === now.getFullYear();
                                    if (isToday) return Theme.bgSolid;
                                    return modelData.current ? Theme.fg : Theme.fgDim;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
