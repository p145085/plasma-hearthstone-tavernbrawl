.pragma library

// Since patch 31.2 every region follows the Americas schedule: a brawl opens Wednesday
// 9:00 AM Pacific time and closes the next Wednesday at 8:00 AM, so the UTC times shift
// with US daylight saving time (17:00 UTC in winter, 16:00 UTC in summer).
var OPEN_HOUR_PT = 9
var DAY_MS = 24 * 3600000

var MONTHS = {
    january: 0, february: 1, march: 2, april: 3, may: 4, june: 5,
    july: 6, august: 7, september: 8, october: 9, november: 10, december: 11
}

// Day of month of the n-th Sunday (1-based) of a month.
function nthSunday(y, m, n) {
    var first = new Date(Date.UTC(y, m, 1)).getUTCDay()
    return 1 + (7 - first) % 7 + (n - 1) * 7
}

// US DST runs from the second Sunday in March to the first Sunday in November. The 2 AM
// switch never matters here since brawls open on Wednesdays.
function pacificDst(y, m, d) {
    if (m > 2 && m < 10)
        return true
    if (m === 2)
        return d >= nthSunday(y, 2, 2)
    if (m === 10)
        return d < nthSunday(y, 10, 1)
    return false
}

// UTC timestamp of 9:00 AM Pacific on the given calendar date.
function openAt(y, m, d) {
    return Date.UTC(y, m, d, OPEN_HOUR_PT + (pacificDst(y, m, d) ? 7 : 8))
}

// "2026-09-30" for a timestamp's UTC date; Pacific 9 AM is the same date in UTC.
function isoDate(t) {
    return new Date(t).toISOString().slice(0, 10)
}

// "September 30, 2026" -> ms timestamp of 9:00 AM Pacific that day, or NaN.
function parseDate(text) {
    var m = /([A-Za-z]+)\s+(\d{1,2}),\s*(\d{4})/.exec(text)
    if (!m)
        return NaN
    var month = MONTHS[m[1].toLowerCase()]
    if (month === undefined)
        return NaN
    return openAt(+m[3], month, +m[2])
}

// Opening time of the weekly brawl period containing `now` (most recent Wednesday 9 AM PT).
function weekStart(now) {
    var d = new Date(now)
    for (var i = 0; i < 8; i++) {
        var day = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate() - i))
        if (day.getUTCDay() !== 3)
            continue
        var t = openAt(day.getUTCFullYear(), day.getUTCMonth(), day.getUTCDate())
        if (t <= now)
            return t
    }
    return NaN
}

function nextWeekStart(t) {
    var d = new Date(t + 7 * DAY_MS)
    return openAt(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate())
}

function stripTemplates(s) {
    // Innermost-first so nested templates and links inside them disappear too.
    var prev
    do {
        prev = s
        s = s.replace(/\{\{[^{}]*\}\}/g, "")
    } while (s !== prev)
    return s
}

// Wikitext of a table cell -> { name, page, reprise }.
function parseTitleCell(cell) {
    cell = cell.replace(/<ref[^>]*\/>/g, "").replace(/<ref[^>]*>[\s\S]*?<\/ref>/g, "")
               .replace(/<nowiki\s*\/>/g, "")
    var page = ""
    var link = /\[\[([^\]|]+)(?:\|([^\]]+))?\]\]/.exec(cell)
    if (link)
        page = link[1].trim()
    var name = cell.replace(/\[\[([^\]|]+)\|([^\]]+)\]\]/g, "$2")
                   .replace(/\[\[([^\]]+)\]\]/g, "$1")
                   .replace(/'''?/g, "")
                   .replace(/\s+/g, " ")
                   .trim()
    var reprise = /^Reprise:\s*/i.test(name)
    name = name.replace(/^Reprise:\s*/i, "")
    return { name: name, page: page, reprise: reprise }
}

// Rows of the wiki's Tavern Brawl history tables. `open`/`end` are the 9 AM PT boundaries;
// the brawl itself closes an hour before `end`.
function parseHistory(wikitext) {
    var rows = []
    var lines = wikitext.split("\n")
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i]
        if (!/^\|\s*\d+/.test(line))
            continue
        var cells = stripTemplates(line.slice(1)).split("||")
        if (cells.length < 4)
            continue
        var num = parseInt(cells[0], 10)
        var open = parseDate(cells[1])
        var end = parseDate(cells[2])
        if (isNaN(num) || isNaN(open) || isNaN(end))
            continue
        var title = parseTitleCell(cells[3])
        rows.push({
            number: num,
            open: open,
            end: end,
            name: title.name,
            page: title.page,
            reprise: title.reprise,
            type: cells.length > 4 ? cells[4].trim() : ""
        })
    }
    return rows
}

// The brawl period containing `now`. Its `key` (the opening date) identifies the brawl, so
// a multi-week brawl keeps one key while every new brawl gets a new one. When the wiki has
// not listed the current brawl yet, falls back to this week with an unknown name.
function current(rows, now) {
    var best = null
    for (var i = 0; i < rows.length; i++) {
        var r = rows[i]
        if (r.open <= now && now < r.end && (!best || r.open > best.open))
            best = r
    }
    if (best)
        return {
            key: isoDate(best.open), known: true, number: best.number, name: best.name,
            page: best.page, reprise: best.reprise, type: best.type,
            open: best.open, end: best.end, close: best.end - 3600000
        }
    var start = weekStart(now)
    var end = nextWeekStart(start)
    return {
        key: isoDate(start), known: false, number: 0, name: "", page: "", reprise: false, type: "",
        open: start, end: end, close: end - 3600000
    }
}

// Keys used to be the opening timestamp; they are now the opening date.
function migrateKey(key) {
    return /^\d{10,}$/.test(key) ? isoDate(+key) : key
}

// Wiki "Type" column -> kind of deck, for the deck label.
function deckKind(type) {
    var t = type.toLowerCase()
    if (t.indexOf("constructed") === 0)
        return "constructed"
    if (t.indexOf("brawliseum") === 0)
        return "brawliseum"
    if (t.indexOf("premade") === 0)
        return "premade"
    if (t.indexOf("random") === 0)
        return "random"
    if (t.indexOf("cooperative") === 0)
        return "coop"
    if (t.indexOf("single") === 0)
        return "single"
    return ""
}

function formatCountdown(ms) {
    var m = Math.max(0, Math.floor(ms / 60000))
    var d = Math.floor(m / 1440)
    var h = Math.floor((m % 1440) / 60)
    m = m % 60
    if (d > 0)
        return d + "d, " + h + "h, " + m + "m"
    if (h > 0)
        return h + "h, " + m + "m"
    return m + "m"
}
