import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

MouseArea {
    id: compact

    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property bool showText: Plasmoid.configuration.showCountdownInPanel && !vertical

    Layout.minimumWidth: vertical ? -1 : row.implicitWidth
    Layout.preferredWidth: Layout.minimumWidth

    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
    onClicked: mouse => {
        if (mouse.button === Qt.MiddleButton)
            root.setDone(!root.done)
        else
            root.expanded = !root.expanded
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        height: parent.height
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            source: root.iconPath
            Layout.preferredHeight: Math.min(compact.height, Kirigami.Units.iconSizes.medium)
            Layout.preferredWidth: Layout.preferredHeight
            Layout.alignment: Qt.AlignVCenter
            opacity: root.done ? 0.55 : 1

            // Green check when done, orange dot while this brawl's pack is still unclaimed.
            Rectangle {
                width: Math.round(parent.width * 0.45)
                height: width
                radius: width / 2
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                color: root.done ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.neutralTextColor
                border.color: Kirigami.Theme.backgroundColor
                border.width: 1

                Kirigami.Icon {
                    visible: root.done
                    anchors.fill: parent
                    anchors.margins: 1
                    source: "checkmark"
                    color: "white"
                    isMask: true
                }
            }
        }

        PlasmaComponents.Label {
            visible: compact.showText
            text: root.countdown
            font.features: { "tnum": 1 }
            opacity: root.done ? 0.6 : 1
            Layout.alignment: Qt.AlignVCenter
            Layout.rightMargin: Kirigami.Units.smallSpacing
        }
    }
}
