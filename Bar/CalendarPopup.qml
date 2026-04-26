import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Core
import qs.Widgets

Item {
    id: root

    property date currentDate: new Date()

    property date viewDate: new Date()
    property int viewYear: viewDate.getFullYear()
    property int viewMonth: viewDate.getMonth()
    property string viewMode: "days"  // "days", "months", "years"

    // Mirrors the parent dropdown's open state. Reset to the current month
    // on each fresh open so the calendar doesn't reopen on whatever month
    // the user last navigated to.
    property bool windowOpen: false
    onWindowOpenChanged: {
        if (windowOpen) {
            viewDate = new Date();
            viewMode = "days";
        }
    }

    readonly property real fullHeight: calContent.implicitHeight + 16

    anchors.fill: parent

    function prevMonth() { viewDate = new Date(viewYear, viewMonth - 1, 1); }
    function nextMonth() { viewDate = new Date(viewYear, viewMonth + 1, 1); }
    function prevYear() { viewDate = new Date(viewYear - 1, viewMonth, 1); }
    function nextYear() { viewDate = new Date(viewYear + 1, viewMonth, 1); }
    function prevYearPage() { viewDate = new Date(viewYear - 12, viewMonth, 1); }
    function nextYearPage() { viewDate = new Date(viewYear + 12, viewMonth, 1); }

    function selectMonth(m) { viewDate = new Date(viewYear, m, 1); viewMode = "days"; }
    function selectYear(y) { viewDate = new Date(y, viewMonth, 1); viewMode = "months"; }

    onViewYearChanged: HolidayService.ensureYear(viewYear)

    readonly property var _monthHolidays: viewMode === "days"
        ? HolidayService.holidaysInMonth(viewYear, viewMonth)
        : []

    component HolidayDot: Rectangle {
        property color dotColor: Theme.accent
        width: 3
        height: 3
        radius: 1.5
        color: dotColor
    }

    ColumnLayout {
        id: calContent
        anchors.fill: parent
        anchors.margins: Theme.spacingNormal
        spacing: Theme.spacingSmall

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
            HoverText {
                visible: root.viewMode === "days"
                text: new Date(root.viewYear, root.viewMonth, 1)
                      .toLocaleDateString(Qt.locale(), "MMMM")
                normalColor: Theme.fg
                font.pixelSize: Theme.fontSize
                font.weight: Font.Medium
                onClicked: root.viewMode = "months"
            }

            Text {
                visible: root.viewMode === "days"
                text: "  "
            }

            // Clickable year
            HoverText {
                visible: root.viewMode === "days"
                text: root.viewYear
                normalColor: Theme.fg
                font.pixelSize: Theme.fontSize
                font.weight: Font.Medium
                onClicked: root.viewMode = "years"
            }

            // Month picker header
            HoverText {
                visible: root.viewMode === "months"
                text: root.viewYear
                normalColor: Theme.fg
                font.pixelSize: Theme.fontSize
                font.weight: Font.Medium
                onClicked: root.viewMode = "years"
            }

            // Year picker header
            Text {
                visible: root.viewMode === "years"
                property int startYear: root.viewYear - root.viewYear % 12
                text: `${startYear} \u2013 ${startYear + 11}`
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
            Layout.alignment: Qt.AlignHCenter
            columns: 7
            columnSpacing: 0
            rowSpacing: 2

            Repeater {
                model: {
                    // 2024-01-01 is Mon, 2023-12-31 is Sun — seed a week starting from either day
                    const names = [];
                    const start = UserSettings.weekStartsOnMonday ? 1 : 0;
                    for (let i = 0; i < 7; i++) {
                        const d = new Date(2024, 0, start + i);
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
            Layout.alignment: Qt.AlignHCenter
            columns: 7
            columnSpacing: 0
            rowSpacing: 2

            Repeater {
                model: {
                    const year = root.viewYear;
                    const month = root.viewMonth;
                    const firstDay = new Date(year, month, 1);
                    const lastDay = new Date(year, month + 1, 0);

                    // JS getDay(): Sun=0..Sat=6 — rotate for Mon-first
                    let startDow = firstDay.getDay();
                    if (UserSettings.weekStartsOnMonday) {
                        startDow = startDow === 0 ? 6 : startDow - 1;
                    }

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
                    id: dayCell
                    required property var modelData

                    readonly property bool isToday: modelData.current
                        && modelData.day === root.currentDate.getDate()
                        && root.viewMonth === root.currentDate.getMonth()
                        && root.viewYear === root.currentDate.getFullYear()
                    readonly property string holidayName: modelData.current
                        ? HolidayService.holidayFor(new Date(root.viewYear, root.viewMonth, modelData.day))
                        : ""

                    width: 32
                    height: 24
                    radius: Theme.radiusTiny
                    color: isToday ? Theme.accent : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: dayCell.modelData.day
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: {
                            if (dayCell.isToday) return Theme.bgSolid;
                            return dayCell.modelData.current ? Theme.fg : Theme.fgDim;
                        }
                    }

                    HolidayDot {
                        visible: dayCell.holidayName !== ""
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 1
                        anchors.horizontalCenter: parent.horizontalCenter
                        dotColor: dayCell.isToday ? Theme.bgSolid : Theme.accent
                    }
                }
            }
        }

        Separator {
            visible: root.viewMode === "days" && root._monthHolidays.length > 0
            topMargin: Theme.spacingSmall
            leftMargin: Theme.spacingLarge
            rightMargin: Theme.spacingLarge
            color: Theme.accent
        }

        ColumnLayout {
            visible: root.viewMode === "days" && root._monthHolidays.length > 0
            Layout.fillWidth: true
            Layout.leftMargin: Theme.spacingNormal
            Layout.rightMargin: Theme.spacingNormal
            Layout.topMargin: Theme.spacingSmall
            spacing: 2

            Repeater {
                model: root._monthHolidays

                RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: Theme.spacingSmall

                    HolidayDot { Layout.alignment: Qt.AlignVCenter }
                    Text {
                        Layout.preferredWidth: 20
                        horizontalAlignment: Text.AlignRight
                        text: modelData.date.getDate()
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMini
                        color: Theme.fgDim
                    }
                    Text {
                        Layout.fillWidth: true
                        text: modelData.name
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMini
                        color: Theme.fg
                        elide: Text.ElideRight
                    }
                }
            }
        }

        component GridPickerCell: Rectangle {
            required property int index
            property bool isCurrent: false
            property string cellText: ""
            signal clicked()

            width: 70
            height: 32
            radius: Theme.radiusSmall
            color: isCurrent ? Theme.accent
                 : cellMouse.containsMouse ? Theme.bgHover : "transparent"

            Text {
                anchors.centerIn: parent
                text: parent.cellText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: parent.isCurrent ? Theme.bgSolid : Theme.fg
            }

            MouseArea {
                id: cellMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: parent.clicked()
            }
        }

        // ── MONTHS VIEW ───────────────────────────
        Grid {
            visible: root.viewMode === "months"
            Layout.alignment: Qt.AlignHCenter
            columns: 3
            columnSpacing: 4
            rowSpacing: 4

            Repeater {
                model: 12

                GridPickerCell {
                    isCurrent: index === root.currentDate.getMonth()
                             && root.viewYear === root.currentDate.getFullYear()
                    cellText: new Date(2024, index, 1).toLocaleDateString(Qt.locale(), "MMM")
                    onClicked: root.selectMonth(index)
                }
            }
        }

        // ── YEARS VIEW ────────────────────────────
        Grid {
            visible: root.viewMode === "years"
            Layout.alignment: Qt.AlignHCenter
            columns: 3
            columnSpacing: 4
            rowSpacing: 4

            Repeater {
                model: 12

                GridPickerCell {
                    property int year: root.viewYear - root.viewYear % 12 + index
                    isCurrent: year === root.currentDate.getFullYear()
                    cellText: String(year)
                    onClicked: root.selectYear(year)
                }
            }
        }
    }
}
