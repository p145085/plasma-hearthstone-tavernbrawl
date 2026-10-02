import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_notifyNewBrawl: notifyNewBrawl.checked
    property alias cfg_reminderHours: reminderHours.value
    property alias cfg_showCountdownInPanel: showCountdown.checked
    property alias cfg_refreshHours: refreshHours.value

    Kirigami.FormLayout {
        QQC2.CheckBox {
            id: notifyNewBrawl
            Kirigami.FormData.label: i18n("Notifications:")
            text: i18n("When a new Tavern Brawl opens")
        }
        RowLayout {
            QQC2.SpinBox {
                id: reminderHours
                from: 0
                to: 72
            }
            QQC2.Label {
                text: reminderHours.value === 0
                    ? i18n("no reminder before it closes")
                    : i18np("hour before it closes, if not done", "hours before it closes, if not done", reminderHours.value)
            }
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.CheckBox {
            id: showCountdown
            Kirigami.FormData.label: i18n("Panel:")
            text: i18n("Show time until the brawl closes")
        }
        QQC2.SpinBox {
            id: refreshHours
            Kirigami.FormData.label: i18n("Refresh every (hours):")
            from: 1
            to: 24
        }
    }
}
