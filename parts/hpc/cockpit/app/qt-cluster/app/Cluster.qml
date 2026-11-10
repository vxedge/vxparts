// The instrument cluster: speed, battery charge and gear from the vehicle's signal plane. Rendered
// offscreen with Qt Quick's software backend, so it needs no GPU or display.
import QtQuick

Window {
    id: root
    width: 800
    height: 300
    visible: true
    color: "#101418"

    // Read back by cluster.py for /state.json: what QML shows, not what Python received.
    property real speed: cluster.speed
    property real soc: cluster.soc
    property int gear: cluster.gear
    property bool connected: cluster.connected

    Row {
        anchors.centerIn: parent
        spacing: 64

        Column {
            spacing: 4
            Text { text: root.speed.toFixed(0); color: "#f2f4f5"; font.pixelSize: 96; font.bold: true }
            Text { text: "km/h"; color: "#8a949c"; font.pixelSize: 24 }
        }
        Column {
            spacing: 4
            Text { text: root.gear === 0 ? "N" : (root.gear < 0 ? "R" : "D" + root.gear); color: "#f2f4f5"; font.pixelSize: 96; font.bold: true }
            Text { text: "gear"; color: "#8a949c"; font.pixelSize: 24 }
        }
        Column {
            spacing: 4
            Text { text: root.soc.toFixed(0) + "%"; color: root.soc < 20 ? "#e5484d" : "#46a758"; font.pixelSize: 96; font.bold: true }
            Text { text: "battery"; color: "#8a949c"; font.pixelSize: 24 }
        }
    }

    Text {
        anchors { bottom: parent.bottom; right: parent.right; margins: 12 }
        text: root.connected ? "signal plane: connected" : "signal plane: waiting"
        color: root.connected ? "#46a758" : "#8a949c"
        font.pixelSize: 16
    }
}
