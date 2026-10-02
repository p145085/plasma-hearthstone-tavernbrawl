import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import "Brawl.js" as Brawl

PlasmaExtras.Representation {
    id: full

    Layout.minimumWidth: Kirigami.Units.gridUnit * 18
    Layout.minimumHeight: Kirigami.Units.gridUnit * 16
    Layout.preferredWidth: Kirigami.Units.gridUnit * 22
    Layout.preferredHeight: Kirigami.Units.gridUnit * 22

    collapseMarginsHint: true

    header: PlasmaExtras.PlasmoidHeading {
        contentItem: RowLayout {
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents.TabBar {
                id: tabs
                Layout.fillWidth: true
                PlasmaComponents.TabButton {
                    text: i18n("This Week")
                }
                PlasmaComponents.TabButton {
                    text: root.log.length > 0 ? i18n("History (%1)", root.log.length) : i18n("History")
                }
            }
            PlasmaComponents.ToolButton {
                icon.name: "view-refresh"
                enabled: !root.loading
                onClicked: root.fetchBrawl()
                PlasmaComponents.ToolTip { text: i18n("Refresh") }
            }
            PlasmaComponents.ToolButton {
                icon.name: "internet-web-browser"
                onClicked: Qt.openUrlExternally(root.brawlUrl)
                PlasmaComponents.ToolTip { text: i18n("Open on Hearthstone Wiki") }
            }
        }
    }

    StackLayout {
        anchors.fill: parent
        currentIndex: tabs.currentIndex

        // ---- This week ----
        ColumnLayout {
            spacing: Kirigami.Units.largeSpacing

            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.largeSpacing
                Layout.leftMargin: Kirigami.Units.largeSpacing
                Layout.rightMargin: Kirigami.Units.largeSpacing
                implicitHeight: info.implicitHeight + Kirigami.Units.largeSpacing * 2
                radius: Kirigami.Units.cornerRadius
                color: Qt.alpha(Kirigami.Theme.textColor, 0.05)
                border.width: root.done ? 2 : 1
                border.color: root.done ? Kirigami.Theme.positiveTextColor : Qt.alpha(Kirigami.Theme.textColor, 0.12)

                Rectangle {
                    width: 4
                    radius: 2
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.margins: Kirigami.Units.smallSpacing
                    color: root.done ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.neutralTextColor
                }

                ColumnLayout {
                    id: info
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.largeSpacing
                    anchors.leftMargin: Kirigami.Units.largeSpacing * 2
                    spacing: Kirigami.Units.smallSpacing

                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        font: Kirigami.Theme.smallFont
                        opacity: 0.7
                        elide: Text.ElideRight
                        text: root.brawl.known
                            ? [i18n("#%1", root.brawl.number), root.brawl.type, root.brawl.reprise ? i18n("Reprise") : ""]
                                  .filter(s => s !== "").join(" · ")
                            : i18n("THIS WEEK")
                    }
                    Kirigami.Heading {
                        Layout.fillWidth: true
                        level: 2
                        wrapMode: Text.WordWrap
                        text: root.brawlName
                    }

                    DeckChip {
                        visible: root.deckText !== ""
                        type: root.brawl.type
                        text: root.deckText
                    }

                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        visible: !root.brawl.known
                        wrapMode: Text.WordWrap
                        opacity: 0.7
                        text: root.loading ? i18n("Checking the wiki…") : i18n("The wiki hasn't listed this week's brawl yet.")
                    }
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        font.features: { "tnum": 1 }
                        wrapMode: Text.WordWrap
                        text: root.closed
                            ? i18n("Closed · next brawl opens in %1", root.countdown)
                            : i18n("Closes in %1 · %2", root.countdown,
                                   Qt.formatDateTime(new Date(root.brawl.close), "ddd hh:mm"))
                    }
                }
            }

            PlasmaComponents.Button {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Math.max(implicitWidth, Kirigami.Units.gridUnit * 12)
                checkable: true
                checked: root.done
                icon.name: root.done ? "checkmark" : "games-highscores"
                text: root.done ? i18n("Done, pack claimed") : i18n("Mark as done")
                onToggled: root.setDone(checked)
            }

            PlasmaComponents.Label {
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.largeSpacing
                Layout.rightMargin: Kirigami.Units.largeSpacing
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                opacity: 0.7
                text: root.done
                    ? i18n("Resets automatically when the next brawl opens.")
                    : i18n("Win a game for the card pack, then tick it off here (or middle-click the panel icon).")
            }

            Item { Layout.fillHeight: true }

            PlasmaComponents.Label {
                Layout.fillWidth: true
                Layout.margins: Kirigami.Units.largeSpacing
                horizontalAlignment: Text.AlignHCenter
                font: Kirigami.Theme.smallFont
                wrapMode: Text.WordWrap
                color: root.errorMsg ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
                opacity: root.errorMsg ? 1 : 0.6
                text: root.errorMsg
                    ? root.errorMsg
                    : root.fetched
                        ? i18n("Schedule from hearthstone.wiki.gg · updated %1", Qt.formatTime(root.lastUpdated, Qt.DefaultLocaleShortDate))
                        : i18n("Loading…")
            }
        }

        // ---- History ----
        ColumnLayout {
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.margins: Kirigami.Units.largeSpacing
                spacing: Kirigami.Units.largeSpacing

                PlasmaComponents.Label {
                    text: root.log.length
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 2.4
                    font.bold: true
                    font.features: { "tnum": 1 }
                    color: root.log.length > 0 ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.textColor
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        font.bold: true
                        elide: Text.ElideRight
                        text: i18np("card pack earned from Tavern Brawl", "card packs earned from Tavern Brawl", root.log.length)
                    }
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        font: Kirigami.Theme.smallFont
                        opacity: 0.7
                        elide: Text.ElideRight
                        visible: root.log.length > 0
                        text: root.log.length > 0
                            ? i18n("Tracked since %1", Qt.formatDate(new Date(root.log[root.log.length - 1].key + "T12:00:00Z"), Qt.DefaultLocaleShortDate))
                            : ""
                    }
                }
            }

            Kirigami.Separator { Layout.fillWidth: true }

            PlasmaComponents.ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ListView {
                    id: historyList
                    clip: true
                    model: root.log

                    PlasmaExtras.PlaceholderMessage {
                        anchors.centerIn: parent
                        width: parent.width - Kirigami.Units.gridUnit * 4
                        visible: historyList.count === 0
                        iconName: "games-highscores"
                        text: i18n("No brawls logged yet")
                        explanation: i18n("Every brawl you mark as done is kept here.")
                    }

                    delegate: PlasmaComponents.ItemDelegate {
                        id: entry
                        required property var modelData
                        width: historyList.width
                        hoverEnabled: true
                        onClicked: Qt.openUrlExternally(root.wikiPage(modelData.page || ""))

                        contentItem: RowLayout {
                            spacing: Kirigami.Units.largeSpacing

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                PlasmaComponents.Label {
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    font.bold: entry.modelData.key === root.brawlKey
                                    text: entry.modelData.name || i18n("Tavern Brawl")
                                }
                                PlasmaComponents.Label {
                                    Layout.fillWidth: true
                                    font: Kirigami.Theme.smallFont
                                    opacity: 0.7
                                    elide: Text.ElideRight
                                    text: [
                                        Qt.formatDate(new Date(entry.modelData.key + "T12:00:00Z"), Qt.DefaultLocaleShortDate),
                                        entry.modelData.number ? i18n("#%1", entry.modelData.number) : "",
                                        root.deckLabel(entry.modelData.type || "")
                                    ].filter(s => s !== "").join(" · ")
                                }
                            }
                            PlasmaComponents.ToolButton {
                                icon.name: "edit-delete-remove"
                                opacity: entry.hovered ? 1 : 0
                                onClicked: root.removeLogEntry(entry.modelData.key)
                                PlasmaComponents.ToolTip { text: i18n("Remove from history") }
                            }
                        }
                    }
                }
            }

            PlasmaComponents.Label {
                Layout.fillWidth: true
                Layout.margins: Kirigami.Units.largeSpacing
                horizontalAlignment: Text.AlignHCenter
                font: Kirigami.Theme.smallFont
                wrapMode: Text.WordWrap
                opacity: 0.6
                text: i18n("Counted from brawls marked done here. Blizzard has no public API for account history.")
            }
        }
    }
}
