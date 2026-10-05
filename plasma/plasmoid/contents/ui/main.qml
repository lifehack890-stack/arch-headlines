import QtQuick
import QtQuick.Layouts
import QtCore
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as Plasma5Support

PlasmoidItem {
    id: root
    Plasmoid.icon: Qt.resolvedUrl("arch-headlines.svg")
    preferredRepresentation: compactRepresentation
    Plasma5Support.DataSource {
        id: newsSource
        engine: "executable"
        connectedSources: ["/usr/bin/cat \"" + root.newsFilePath + "\""]

        onNewData: function(sourceName, data) {
            try {
                const parsed = JSON.parse(data.stdout)
                root.newsItems = parsed.items || []
                root.unreadCount = parsed.unread_count || 0
            } catch (e) {
                console.log("arch-headlines JSON parse failed:", e)
            }
        }
    }

    Plasma5Support.DataSource {
        id: markAllReadSource
        engine: "executable"

        onNewData: function(sourceName, data) {
            try {
                const parsed = JSON.parse(data.stdout)
                root.newsItems = parsed.items || []
                root.unreadCount = parsed.unread_count || 0
            } catch (e) {
                console.log("arch-headlines mark-all-read failed:", e)
            }

            disconnectSource(sourceName)
        }
    }


    property string dataRoot: StandardPaths.writableLocation(StandardPaths.GenericDataLocation)
    property string newsFileUrl: dataRoot + "/arch-headlines-plasma/news.json"
    property string newsFilePath: newsFileUrl.replace("file://", "")
    property var newsItems: []
    function relativeTime(isoString) {
        if (!isoString)
            return "--"

        const then = new Date(isoString)
        const now = new Date()
        const diffMs = now.getTime() - then.getTime()

        if (isNaN(diffMs))
            return "--"

        const minutes = Math.floor(diffMs / 60000)
        const hours = Math.floor(diffMs / 3600000)
        const days = Math.floor(diffMs / 86400000)

        if (minutes < 1)
            return "now"
        if (minutes < 60)
            return minutes + "m ago"
        if (hours < 24)
            return hours + "h ago"
        return days + "d ago"
    }


    // Step 2: temporary unread count for badge testing.
    property int unreadCount: 0

    compactRepresentation: Item {
        id: compact

        Layout.preferredWidth: Kirigami.Units.iconSizes.medium
        Layout.preferredHeight: Kirigami.Units.iconSizes.medium

        Item {
            id: logoContainer

            anchors.fill: parent

            Kirigami.Icon {
                id: notificationIcon

                anchors.fill: parent
                source: Qt.resolvedUrl("arch-headlines.svg")
                active: mouseArea.containsMouse
            }

            // Windows / Thunderbird-style unread badge.
            Item {
                id: unreadBadgeAnchor

                visible: root.unreadCount > 0

                property real badgeSize: Math.max(
                    10,
                    Math.min(
                        parent.width * 0.52,
                        parent.height * 0.52
                    )
                )

                width: root.unreadCount > 99 ? badgeSize * 1.45 : badgeSize
                height: badgeSize

                anchors.right: parent.right
                anchors.rightMargin: -2
                anchors.bottom: parent.bottom
                anchors.bottomMargin: -2

                Rectangle {
                    id: unreadBadge

                    anchors.fill: parent
                    radius: width / 2

                    color: "#e81123"

                    Text {
                        anchors.centerIn: parent

                        text: root.unreadCount > 99
                              ? "99+"
                              : String(root.unreadCount)

                        color: "white"

                        font.pixelSize: Math.max(
                            7,
                            unreadBadge.height * (
                                root.unreadCount > 99 ? 0.28 : 0.42
                            )
                        )

                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        minimumPixelSize: 1
                    }
                }
            }
        }

        MouseArea {
            id: mouseArea

            anchors.fill: parent

            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onClicked: {
                root.expanded = !root.expanded
            }
        }
    }

    fullRepresentation: Item {
        id: popup

        implicitWidth: 360
        implicitHeight: 360

        Layout.minimumWidth: 320
        Layout.minimumHeight: 220

        Rectangle {
            id: surface

            anchors.fill: parent
            radius: 16

            color: "#1E2024"

            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.10)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16

                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 12

                    spacing: 8

                    Image {
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24

                        source: Qt.resolvedUrl("arch-headlines.svg")
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                    }

                    Text {
                        Layout.fillWidth: true

                        text: "Arch Headlines"
                        color: "#F2F4F7"

                        font.pixelSize: 15
                        font.weight: Font.Medium
                    }
                }

                ColumnLayout {
                    id: articleArea

                    Layout.fillWidth: true
                    Layout.fillHeight: false

                    spacing: 0

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 60

                        radius: 10
                        color: articleMouse1.containsMouse
                               ? Qt.rgba(1, 1, 1, 0.06)
                               : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            anchors.topMargin: 10
                            anchors.bottomMargin: 10

                            spacing: 10

                            Rectangle {
                                Layout.preferredWidth: 8
                                Layout.preferredHeight: 8
                                Layout.alignment: Qt.AlignTop
                                Layout.topMargin: 6

                                radius: 4
                                color: root.newsItems.length > 0 && root.newsItems[0].unread ? "#1793D1" : "transparent"
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                Text {
                                    Layout.fillWidth: true
                                    text: root.newsItems.length > 0 ? root.newsItems[0].title : "Sample headline one"
                                    color: "#F2F4F7"
                                    font.pixelSize: 14
                                    font.weight: Font.Medium
                                    wrapMode: Text.WordWrap
                                }

                                Text {
                                    text: root.newsItems.length > 0 ? "archlinux.org · " + root.relativeTime(root.newsItems[0].date) : "archlinux.org · --"
                                    color: "#9AA3AE"
                                    font.pixelSize: 12
                                }
                            }
                        }

                        MouseArea {
                            id: articleMouse1
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                if (root.newsItems.length > 0)
                                    Qt.openUrlExternally(root.newsItems[0].link)
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 80

                        radius: 10
                        color: articleMouse2.containsMouse
                               ? Qt.rgba(1, 1, 1, 0.06)
                               : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            anchors.topMargin: 10
                            anchors.bottomMargin: 10

                            spacing: 10

                            Rectangle {
                                Layout.preferredWidth: 8
                                Layout.preferredHeight: 8
                                Layout.alignment: Qt.AlignTop
                                Layout.topMargin: 6

                                radius: 4
                                color: root.newsItems.length > 1 && root.newsItems[1].unread ? "#1793D1" : "transparent"
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                Text {
                                    Layout.fillWidth: true
                                    text: root.newsItems.length > 1 ? root.newsItems[1].title : "Sample headline two"
                                    color: "#F2F4F7"
                                    font.pixelSize: 14
                                    font.weight: Font.Medium
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: root.newsItems.length > 1 ? "archlinux.org · " + root.relativeTime(root.newsItems[1].date) : "archlinux.org · --"
                                    color: "#9AA3AE"
                                    font.pixelSize: 12
                                }
                            }
                        }

                        MouseArea {
                            id: articleMouse2
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                if (root.newsItems.length > 1)
                                    Qt.openUrlExternally(root.newsItems[1].link)
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 60

                        radius: 10
                        color: articleMouse3.containsMouse
                               ? Qt.rgba(1, 1, 1, 0.06)
                               : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            anchors.topMargin: 10
                            anchors.bottomMargin: 10

                            spacing: 10

                            Rectangle {
                                Layout.preferredWidth: 8
                                Layout.preferredHeight: 8
                                Layout.alignment: Qt.AlignTop
                                Layout.topMargin: 6

                                radius: 4
                                color: root.newsItems.length > 2 && root.newsItems[2].unread ? "#1793D1" : "transparent"
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                Text {
                                    Layout.fillWidth: true
                                    text: root.newsItems.length > 2 ? root.newsItems[2].title : "Sample headline three"
                                    color: "#F2F4F7"
                                    font.pixelSize: 14
                                    font.weight: Font.Medium
                                    wrapMode: Text.WordWrap
                                }

                                Text {
                                    text: root.newsItems.length > 2 ? "archlinux.org · " + root.relativeTime(root.newsItems[2].date) : "archlinux.org · --"
                                    color: "#9AA3AE"
                                    font.pixelSize: 12
                                }
                            }
                        }

                        MouseArea {
                            id: articleMouse3
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                if (root.newsItems.length > 2)
                                    Qt.openUrlExternally(root.newsItems[2].link)
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 60

                        radius: 10
                        color: articleMouse4.containsMouse
                               ? Qt.rgba(1, 1, 1, 0.06)
                               : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            anchors.topMargin: 10
                            anchors.bottomMargin: 10

                            spacing: 10

                            Rectangle {
                                Layout.preferredWidth: 8
                                Layout.preferredHeight: 8
                                Layout.alignment: Qt.AlignTop
                                Layout.topMargin: 6

                                radius: 4
                                color: root.newsItems.length > 3 && root.newsItems[3].unread ? "#1793D1" : "transparent"
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                Text {
                                    Layout.fillWidth: true
                                    text: root.newsItems.length > 3 ? root.newsItems[3].title : "Sample headline four"
                                    color: "#F2F4F7"
                                    font.pixelSize: 14
                                    font.weight: Font.Medium
                                    wrapMode: Text.WordWrap
                                }

                                Text {
                                    text: root.newsItems.length > 3 ? "archlinux.org · " + root.relativeTime(root.newsItems[3].date) : "archlinux.org · --"
                                    color: "#9AA3AE"
                                    font.pixelSize: 12
                                }
                            }
                        }

                        MouseArea {
                            id: articleMouse4
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                if (root.newsItems.length > 3)
                                    Qt.openUrlExternally(root.newsItems[3].link)
                            }
                        }
                    }
                }
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    Layout.topMargin: 8
                    Layout.bottomMargin: 12

                    color: Qt.rgba(1, 1, 1, 0.08)
                }

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        Layout.fillWidth: true
                        text: Math.min(root.newsItems.length, 4) + " articles, " + root.unreadCount + " unread"
                        color: "#9AA3AE"
                        font.pixelSize: 12
                    }

                    Text {
                        text: "Mark all as read"
                        color: "#1793D1"
                        font.pixelSize: 12

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                markAllReadSource.connectSource(
                                    root.dataRoot.replace("file://", "") +
                                    "/arch-headlines-plasma/mark-all-read.sh"
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}
