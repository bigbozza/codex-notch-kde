import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: root

    property string status: "loading"
    property string errorMessage: ""
    property bool hasSnapshot: false
    property bool refreshing: true
    property string plan: "Unavailable"
    property string creditsRemaining: ""
    property real weeklyRemaining: -1
    property real weeklyResetAt: 0
    property real weeklyWindowSeconds: 0
    property int resetCredits: -1
    property real resetCreditGrantedAt: 0
    property real resetCreditExpiry: 0
    property real fetchedAt: 0
    property real nowEpoch: Date.now() / 1000

    readonly property string helperUrl: Qt.resolvedUrl("../code/codex_usage.py").toString()
    readonly property string helperPath: decodeURIComponent(helperUrl.replace(/^file:\/\//, ""))
    readonly property string helperCommand: helperPath
    readonly property string compactText: weeklyRemaining < 0
        ? "--"
        : Math.round(weeklyRemaining) + "%"
    readonly property bool hasCredits: creditsRemaining.length > 0
    readonly property bool hasResetCredits: resetCredits >= 0
    readonly property real weeklyResetProgress: weeklyResetAt > 0 && weeklyWindowSeconds > 0
        ? Math.max(0, Math.min(1, (weeklyResetAt - nowEpoch) / weeklyWindowSeconds))
        : -1
    readonly property real resetCreditProgress: resetCreditExpiry > 0
        && resetCreditGrantedAt > 0
        && resetCreditExpiry > resetCreditGrantedAt
        ? Math.max(0, Math.min(1,
            (resetCreditExpiry - nowEpoch) / (resetCreditExpiry - resetCreditGrantedAt)))
        : -1
    readonly property string resetRemainingText: weeklyResetAt > 0
        ? formatDuration(Math.max(0, weeklyResetAt - nowEpoch))
        : "Unavailable"
    readonly property color quotaColor: weeklyRemaining >= 0 && weeklyRemaining <= 10
        ? Kirigami.Theme.negativeTextColor
        : weeklyRemaining >= 0 && weeklyRemaining <= 20
            ? Kirigami.Theme.neutralTextColor
            : Kirigami.Theme.highlightColor
    readonly property string statusMessage: {
        if (refreshing && !hasSnapshot) {
            return "Loading Codex quota...";
        }
        if (status === "sign_in_required") {
            return errorMessage || "Sign in with Codex to load quota";
        }
        if (status === "stale") {
            return (errorMessage || "Could not refresh quota") + ". Showing the last result.";
        }
        if (status === "unavailable") {
            return errorMessage || "Codex quota is unavailable";
        }
        return "Codex quota is ready";
    }
    readonly property string updatedText: fetchedAt > 0
        ? "Updated " + relativeAge(Math.max(0, nowEpoch - fetchedAt))
        : "Not updated yet"

    Plasmoid.icon: "office-chart-pie"
    toolTipMainText: "Codex quota"
    toolTipSubText: hasSnapshot
        ? "Weekly remaining: " + compactText + " | " + resetRemainingText + " to reset"
        : statusMessage

    compactRepresentation: CompactRepresentation {
        controller: root
    }

    fullRepresentation: FullRepresentation {
        controller: root
    }

    function numberOr(value, fallback) {
        return typeof value === "number" && isFinite(value) ? value : fallback;
    }

    function applyPayload(payload) {
        refreshing = false;
        if (payload.status !== "ok") {
            errorMessage = typeof payload.message === "string" ? payload.message : "Codex quota could not be loaded";
            status = hasSnapshot ? "stale" : (payload.status || "unavailable");
            return;
        }

        status = "ok";
        errorMessage = "";
        hasSnapshot = true;
        plan = typeof payload.plan === "string" ? payload.plan : "Unavailable";
        creditsRemaining = payload.credits_remaining === null
            || payload.credits_remaining === undefined
            ? ""
            : String(payload.credits_remaining);
        weeklyRemaining = numberOr(payload.weekly_remaining_percent, -1);
        weeklyResetAt = numberOr(payload.weekly_reset_at, 0);
        weeklyWindowSeconds = numberOr(payload.weekly_window_seconds, 0);
        resetCredits = Number.isInteger(payload.reset_credits_count)
            ? payload.reset_credits_count
            : -1;
        resetCreditGrantedAt = numberOr(payload.reset_credit_granted_at, 0);
        resetCreditExpiry = numberOr(payload.reset_credit_expiry, 0);
        fetchedAt = numberOr(payload.fetched_at, nowEpoch);
    }

    function refresh() {
        refreshing = true;
        usageSource.disconnectSource(helperCommand);
        reconnectTimer.restart();
    }

    function formatDuration(seconds) {
        var totalMinutes = Math.max(0, Math.floor(seconds / 60));
        var days = Math.floor(totalMinutes / 1440);
        var hours = Math.floor(totalMinutes / 60) % 24;
        var minutes = totalMinutes % 60;
        if (days > 0) {
            return days + "d " + hours + "h";
        }
        if (hours > 0) {
            return hours + "h " + minutes + "m";
        }
        return totalMinutes > 0 ? totalMinutes + "m" : "<1m";
    }

    function formatDate(epoch) {
        return Qt.formatDateTime(new Date(epoch * 1000), "MMM d, yyyy 'at' HH:mm");
    }

    function relativeAge(seconds) {
        if (seconds < 60) {
            return "just now";
        }
        if (seconds < 3600) {
            return Math.floor(seconds / 60) + "m ago";
        }
        return Math.floor(seconds / 3600) + "h ago";
    }

    Plasma5Support.DataSource {
        id: usageSource
        engine: "executable"
        interval: 60000
        connectedSources: [root.helperCommand]

        onNewData: function(sourceName, data) {
            var output = data["stdout"];
            if (typeof output !== "string" || output.trim().length === 0) {
                root.applyPayload({
                    "status": "unavailable",
                    "message": "Codex quota helper returned no data"
                });
                return;
            }
            try {
                root.applyPayload(JSON.parse(output));
            } catch (error) {
                root.applyPayload({
                    "status": "unavailable",
                    "message": "Codex quota helper returned invalid data"
                });
            }
        }
    }

    Timer {
        interval: 30000
        repeat: true
        running: true
        onTriggered: root.nowEpoch = Date.now() / 1000
    }

    Timer {
        id: reconnectTimer
        interval: 50
        repeat: false
        onTriggered: usageSource.connectSource(root.helperCommand)
    }
}
