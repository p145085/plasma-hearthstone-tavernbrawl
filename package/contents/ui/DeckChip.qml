import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import "Brawl.js" as Brawl

// Pill saying whether you bring your own deck or one is handed to you.
Rectangle {
    id: chip

    property string type
    property string text

    readonly property string kind: Brawl.deckKind(type)
    readonly property bool ownDeck: kind === "constructed" || kind === "brawliseum"
    readonly property color tint: ownDeck ? Kirigami.Theme.linkColor : Kirigami.Theme.positiveTextColor

    implicitWidth: row.implicitWidth + Kirigami.Units.largeSpacing * 2
    implicitHeight: row.implicitHeight + Kirigami.Units.smallSpacing * 2
    Layout.maximumWidth: parent ? parent.width : implicitWidth
    radius: height / 2
    color: Qt.alpha(tint, 0.15)
    border.color: Qt.alpha(tint, 0.5)

    RowLayout {
        id: row
        anchors.centerIn: parent
        width: Math.min(implicitWidth, chip.width - Kirigami.Units.largeSpacing * 2)
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            source: chip.ownDeck ? "document-edit" : chip.kind === "single" ? "user" : "view-media-playlist"
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Layout.preferredWidth
            color: chip.tint
        }
        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: chip.text
            elide: Text.ElideRight
            color: chip.tint
            font.bold: true
        }
    }
}
