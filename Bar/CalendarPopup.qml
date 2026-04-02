import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Config
import qs.Widgets

AnimatedPopup {
    id: root

    property date currentDate: new Date()

    property date viewDate: new Date()
    property int viewYear: viewDate.getFullYear()
    property int viewMonth: viewDate.getMonth()
    property string viewMode: "days"  // "days", "months", "years"

    fullHeight: calContent.implicitHeight + 16
    implicitWidth: 240

    function prevMonth() { viewDate = new Date(viewYear, viewMonth - 1, 1); }
    function nextMonth() { viewDate = new Date(viewYear, viewMonth + 1, 1); }
    function prevYear() { viewDate = new Date(viewYear - 1, viewMonth, 1); }
    function nextYear() { viewDate = new Date(viewYear + 1, viewMonth, 1); }
    function prevYearPage() { viewDate = new Date(viewYear - 12, viewMonth, 1); }
    function nextYearPage() { viewDate = new Date(viewYear + 12, viewMonth, 1); }

    function selectMonth(m) { viewDate = new Date(viewYear, m, 1); viewMode = "days"; }
    function selectYear(y) { viewDate = new Date(y, viewMonth, 1); viewMode = "months"; }

    ColumnLayout {
        id: calContent
        anchors.fill: parent
        anchors.margins: 8
        spacing: 6

        // ── Header with nav ────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            IconButton {
                icon: Theme.iconArrowLeft
                size: 12
                normalColor: Theme.fgDim
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                onClicked: {
                    if (root.viewMode === "days") root.prevMonth();
                    else if (root.viewMode === "months") root.prevYear();
                    else root.prevYearPage();
                }
            }

            Item { Layout.fillWidth: true }

            // Clickable month
            Text {
                visible: root.viewMode === "days"
                text: new Date(root.viewYear, root.viewMonth, 1)
                      .toLocaleDateString(Qt.locale(), "MMMM")
                color: monthMouse.containsMouse ? Theme.accent : Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.weight: Font.Medium
                MouseArea {
                    id: monthMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.viewMode = "months"
                }
            }

            Text {
                visible: root.viewMode === "days"
                text: "  "
            }

            // Clickable year
            Text {
                visible: root.viewMode === "days"
                text: root.viewYear
                color: yearMouse.containsMouse ? Theme.accent : Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.weight: Font.Medium
                MouseArea {
                    id: yearMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.viewMode = "years"
                }
            }

            // Month picker header
            Text {
                visible: root.viewMode === "months"
                text: root.viewYear
                color: yearMouse2.containsMouse ? Theme.accent : Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.weight: Font.Medium
                MouseArea {
                    id: yearMouse2
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.viewMode = "years"
                }
            }

            // Year picker header
            Text {
                visible: root.viewMode === "years"
                property int startYear: root.viewYear - root.viewYear % 12
                text: startYear + " \u2013 " + (startYear + 11)
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.weight: Font.Medium
            }

            Item { Layout.fillWidth: true }

            IconButton {
                icon: Theme.iconArrowRight
                size: 12
                normalColor: Theme.fgDim
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                onClicked: {
                    if (root.viewMode === "days") root.nextMonth();
                    else if (root.viewMode === "months") root.nextYear();
                    else root.nextYearPage();
                }
            }
        }

        // ── DAYS VIEW ─────────────────────────────
        // Day-of-week headers
        Grid {
            visible: root.viewMode === "days"
            Layout.fillWidth: true
            columns: 7
            columnSpacing: 0
            rowSpacing: 2

            Repeater {
                model: {
                    const names = [];
                    for (let i = 1; i <= 7; i++) {
                        const d = new Date(2024, 0, i);
                        names.push(d.toLocaleDateString(Qt.locale(), "ddd").substring(0, 2));
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
            visible: root.viewMode === "days"
            Layout.fillWidth: true
            columns: 7
            columnSpacing: 0
            rowSpacing: 2

            Repeater {
                model: {
                    const year = root.viewYear;
                    const month = root.viewMonth;
                    const firstDay = new Date(year, month, 1);
                    const lastDay = new Date(year, month + 1, 0);

                    let startDow = firstDay.getDay() - 1;
                    if (startDow < 0) startDow = 6;

                    const cells = [];
                    const prevLast = new Date(year, month, 0).getDate();
                    for (let i = startDow - 1; i >= 0; i--)
                        cells.push({ day: prevLast - i, current: false });
                    for (let d = 1; d <= lastDay.getDate(); d++)
                        cells.push({ day: d, current: true });
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
                            && root.viewMonth === now.getMonth()
                            && root.viewYear === now.getFullYear())
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
                                && root.viewMonth === now.getMonth()
                                && root.viewYear === now.getFullYear();
                            if (isToday) return Theme.bgSolid;
                            return modelData.current ? Theme.fg : Theme.fgDim;
                        }
                    }
                }
            }
        }

        // ── MONTHS VIEW ───────────────────────────
        Grid {
            visible: root.viewMode === "months"
            Layout.fillWidth: true
            columns: 3
            columnSpacing: 4
            rowSpacing: 4

            Repeater {
                model: 12

                Rectangle {
                    required property int index
                    width: 70
                    height: 32
                    radius: 6
                    color: {
                        if (index === root.currentDate.getMonth()
                            && root.viewYear === root.currentDate.getFullYear())
                            return Theme.accent;
                        return mMouse.containsMouse ? Theme.bgHover : "transparent";
                    }

                    Text {
                        anchors.centerIn: parent
                        text: new Date(2024, index, 1).toLocaleDateString(Qt.locale(), "MMM")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: {
                            if (index === root.currentDate.getMonth()
                                && root.viewYear === root.currentDate.getFullYear())
                                return Theme.bgSolid;
                            return Theme.fg;
                        }
                    }

                    MouseArea {
                        id: mMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selectMonth(index)
                    }
                }
            }
        }

        // ── YEARS VIEW ────────────────────────────
        Grid {
            visible: root.viewMode === "years"
            Layout.fillWidth: true
            columns: 3
            columnSpacing: 4
            rowSpacing: 4

            Repeater {
                model: 12

                Rectangle {
                    required property int index
                    property int year: root.viewYear - root.viewYear % 12 + index
                    width: 70
                    height: 32
                    radius: 6
                    color: {
                        if (year === root.currentDate.getFullYear())
                            return Theme.accent;
                        return yMouse.containsMouse ? Theme.bgHover : "transparent";
                    }

                    Text {
                        anchors.centerIn: parent
                        text: parent.year
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: {
                            if (parent.year === root.currentDate.getFullYear())
                                return Theme.bgSolid;
                            return Theme.fg;
                        }
                    }

                    MouseArea {
                        id: yMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selectYear(parent.year)
                    }
                }
            }
        }
    }
}
