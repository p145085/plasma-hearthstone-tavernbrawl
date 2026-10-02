import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.notification
import "Brawl.js" as Brawl

PlasmoidItem {
    id: root

    readonly property string wikiBase: "https://hearthstone.wiki.gg/wiki/"
    readonly property string apiUrl: wikiBase + "Tavern_Brawl?action=raw"
    readonly property string homepage: Plasmoid.metaData.website
    readonly property string iconPath: Qt.resolvedUrl("../icons/tavernbrawl.svg").toString().replace("file://", "")

    // Most recent rows of the wiki's history table; cached in config so the widget
    // still knows the brawl (and its multi-week span) when started offline.
    property var rows: []
    property string errorMsg: ""
    property bool loading: false
    property date lastUpdated
    property bool fetched: false

    property real now: Date.now()
    readonly property var brawl: Brawl.current(rows, now)
    readonly property string brawlKey: brawl.key
    readonly property real msLeft: brawl.close - now
    // The hour between a brawl closing and the next one opening.
    readonly property bool closed: msLeft <= 0
    readonly property string countdown: Brawl.formatCountdown(closed ? brawl.end - now : msLeft)
    readonly property string brawlName: brawl.known ? brawl.name : i18n("New Tavern Brawl")
    readonly property string deckText: deckLabel(brawl.type)
    readonly property string brawlUrl: wikiPage(brawl.page)

    // Completed brawls, newest first: { key, number, name, type, page, doneAt }.
    readonly property var log: parseLog(Plasmoid.configuration.completedLog)
    // Done is tied to the brawl's key, so it clears itself when a new brawl opens.
    readonly property bool done: log.some(e => e.key === brawlKey)

    function deckLabel(type) {
        switch (Brawl.deckKind(type)) {
        case "constructed": return i18n("Build your own deck")
        case "brawliseum": return i18n("Build your own deck (Brawliseum run)")
        case "premade": return i18n("Deck provided (pick a premade)")
        case "random": return i18n("Deck provided (randomized)")
        case "coop": return i18n("Co-op, deck depends on the brawl")
        case "single": return i18n("Single-player against the AI")
        default: return ""
        }
    }

    function wikiPage(page) {
        return page !== ""
            ? wikiBase + encodeURIComponent(page.replace(/ /g, "_")).replace(/%2F/g, "/")
            : wikiBase + "Tavern_Brawl"
    }

    function parseLog(json) {
        try {
            var list = JSON.parse(json || "[]")
            return Array.isArray(list) ? list : []
        } catch (e) {
            return []
        }
    }

    function saveLog(list) {
        list.sort((a, b) => a.key < b.key ? 1 : a.key > b.key ? -1 : 0)
        Plasmoid.configuration.completedLog = JSON.stringify(list)
    }

    function setDone(on) {
        var list = log.filter(e => e.key !== brawlKey)
        if (on)
            list.push({
                key: brawlKey, number: brawl.number, name: brawl.name, type: brawl.type,
                page: brawl.page, doneAt: Date.now()
            })
        saveLog(list)
    }

    function removeLogEntry(key) {
        saveLog(log.filter(e => e.key !== key))
    }

    // Fill in names for brawls ticked off before the wiki had listed them.
    function enrichLog() {
        var changed = false
        var list = log.map(function (e) {
            if (e.name)
                return e
            var r = rows.find(r => Brawl.isoDate(r.open) === e.key)
            if (!r)
                return e
            changed = true
            return Object.assign({}, e, { number: r.number, name: r.name, type: r.type, page: r.page })
        })
        if (changed)
            saveLog(list)
    }

    function migrateConfig() {
        var cfg = Plasmoid.configuration
        cfg.announcedKey = Brawl.migrateKey(cfg.announcedKey)
        cfg.remindedKey = Brawl.migrateKey(cfg.remindedKey)
        if (cfg.completedKey !== "") {
            var key = Brawl.migrateKey(cfg.completedKey)
            if (!log.some(e => e.key === key))
                saveLog(log.concat([{ key: key, number: 0, name: "", type: "", page: "", doneAt: Date.now() }]))
            cfg.completedKey = ""
        }
    }

    function loadCache() {
        var cached = parseLog(Plasmoid.configuration.cachedSchedule)
        rows = cached.filter(r => r.end !== undefined)
    }

    function fetchBrawl() {
        loading = true
        var xhr = new XMLHttpRequest()
        xhr.open("GET", apiUrl + "&t=" + Date.now())
        // wiki.gg rejects the bare "Mozilla/5.0" Qt sends by default.
        xhr.setRequestHeader("User-Agent", "plasma-hearthstone-tavernbrawl/" + Plasmoid.metaData.version + " (+" + homepage + ")")
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return
            loading = false
            if (xhr.status !== 200) {
                errorMsg = i18n("Hearthstone Wiki returned HTTP %1", xhr.status || "error")
                retryTimer.restart()
                return
            }
            var parsed = Brawl.parseHistory(xhr.responseText)
            if (parsed.length === 0) {
                errorMsg = i18n("Could not read the Tavern Brawl schedule")
                retryTimer.restart()
                return
            }
            parsed.sort((a, b) => b.open - a.open)
            rows = parsed.slice(0, 12)
            Plasmoid.configuration.cachedSchedule = JSON.stringify(rows)
            errorMsg = ""
            fetched = true
            lastUpdated = new Date()
            enrichLog()
            checkNotifications()
        }
        xhr.send()
    }

    function notify(title, text) {
        var n = notificationComponent.createObject(root, { title: title, text: text })
        n.sendEvent()
    }

    function checkNotifications() {
        var cfg = Plasmoid.configuration
        var b = brawl
        if (cfg.announcedKey !== b.key) {
            // Wait for the wiki to name the brawl, but not forever.
            var named = b.known || (fetched && now - b.open > 6 * 3600000)
            if (cfg.announcedKey === "") {
                cfg.announcedKey = b.key    // first run: nothing is "new"
            } else if (named) {
                cfg.announcedKey = b.key
                if (cfg.notifyNewBrawl && !done)
                    notify(i18n("New Tavern Brawl"),
                           (b.known ? i18n("%1 is open. Win a game for this week's card pack.", b.name)
                                    : i18n("A new Tavern Brawl is open. Win a game for this week's card pack."))
                           + (deckText ? "\n" + deckText : ""))
            }
        }
        var remMs = cfg.reminderHours * 3600000
        if (!done && !closed && cfg.reminderHours > 0 && msLeft <= remMs && cfg.remindedKey !== b.key) {
            cfg.remindedKey = b.key
            notify(i18n("Tavern Brawl closing soon"),
                   i18n("%1 closes in %2 and you haven't marked it done.", brawlName, countdown))
        }
    }

    onBrawlKeyChanged: {
        // A new week the wiki may not have listed yet.
        if (!brawl.known)
            fetchBrawl()
    }

    Component {
        id: notificationComponent
        Notification {
            componentName: "plasma_workspace"
            eventId: "notification"
            iconName: root.iconPath
            autoDelete: true
        }
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.now = Date.now()
            root.checkNotifications()
        }
    }

    Timer {
        interval: root.brawl.known
            ? Math.max(1, Plasmoid.configuration.refreshHours) * 3600000
            : 15 * 60000
        running: true
        repeat: true
        onTriggered: root.fetchBrawl()
    }

    Timer {
        id: retryTimer
        interval: 5 * 60000
        onTriggered: root.fetchBrawl()
    }

    Component.onCompleted: {
        migrateConfig()
        loadCache()
        fetchBrawl()
    }

    Plasmoid.icon: iconPath

    toolTipMainText: done ? i18n("Tavern Brawl: done ✓") : i18n("Tavern Brawl: not done yet")
    toolTipSubText: [
        brawlName,
        deckText,
        closed ? i18n("Closed, next brawl opens in %1", countdown) : i18n("Closes in %1", countdown),
        errorMsg
    ].filter(s => s !== "").join("\n")

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Done this week")
            icon.name: "checkmark"
            checkable: true
            checked: root.done
            onTriggered: root.setDone(checked)
        },
        PlasmaCore.Action {
            text: i18n("Refresh")
            icon.name: "view-refresh"
            onTriggered: root.fetchBrawl()
        },
        PlasmaCore.Action {
            text: i18n("Open on Hearthstone Wiki")
            icon.name: "internet-web-browser"
            onTriggered: Qt.openUrlExternally(root.brawlUrl)
        }
    ]

    compactRepresentation: CompactView {}
    fullRepresentation: FullView {}
}
