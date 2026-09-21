import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore

PlasmoidItem {
    id: root

    Layout.minimumWidth: 220
    Layout.minimumHeight: 260
    Layout.preferredWidth: 300
    Layout.preferredHeight: 320

    preferredRepresentation: fullRepresentation

    // No card behind the gallows; the desktop shows through. Deliberately not
    // ConfigurableBackground -- that flag lets a stored userBackgroundHints
    // override this and put the card back.
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    fullRepresentation: Item {
        id: scene
        anchors.fill: parent

        // Same cream the character is drawn in.
        readonly property color creamColor: "#f1e5cd"
        readonly property color creamShade: "#d4c8b0"

        // --- Pendulum state (radians, 0 = hanging straight down) ---
        property real angle: 0.15
        property real angVel: 0
        // The body's own twist relative to the rope, so it lags behind the
        // swing and settles a beat later instead of moving as one rigid slab.
        property real twist: 0
        property real twistVel: 0

        readonly property real gravity: 9.81
        readonly property real ropeLen: 1.35      // metres; sets the swing period
        readonly property real linearDrag: 0.10   // friction at the knot
        readonly property real quadDrag: 0.020    // air resistance, grows with speed
        readonly property real twistStiffness: 40
        readonly property real twistDamping: 3.2
        readonly property real twistCoupling: 0.16
        readonly property real maxAngVel: 14

        // Speed needed at the bottom to make it all the way over the beam.
        readonly property real loopSpeed: 2 * Math.sqrt(gravity / ropeLen)

        property bool dragging: false
        property real lastClickMs: 0
        // Steady push from a hovering cursor, applied as a force and decayed
        // per frame -- adding straight to angVel per mouse event made a single
        // sweep across the widget worth hundreds of nudges.
        property real hoverTorque: 0

        property real attachX: beam.x + beam.width * 0.12
        property real attachY: beam.y + beam.height
        // Distance from the knot down to the middle of the body, in pixels.
        readonly property real bobDist: rope.height + figure.height * 0.5

        function bobX() { return attachX + Math.sin(angle) * bobDist }
        function bobY() { return attachY + Math.cos(angle) * bobDist }

        function integrate(h) {
            // Full nonlinear pendulum -- sin(angle), not the small-angle
            // approximation, so it behaves correctly all the way over the top.
            var acc = -(gravity / ropeLen) * Math.sin(angle)
                      - linearDrag * angVel
                      - quadDrag * angVel * Math.abs(angVel)
                      + hoverTorque

            angVel += acc * h
            angVel = Math.max(-maxAngVel, Math.min(maxAngVel, angVel))
            angle += angVel * h

            // Wrapping by a whole turn is visually identical but keeps the
            // float from drifting during long spins.
            if (angle > Math.PI) angle -= 2 * Math.PI
            else if (angle < -Math.PI) angle += 2 * Math.PI

            // Body twist: a spring back to straight, shaken by the rope's
            // acceleration.
            var tAcc = -twistStiffness * twist - twistDamping * twistVel - twistCoupling * acc
            twistVel += tAcc * h
            twist += twistVel * h
        }

        // Only the horizontal crossbar is shown, emerging from the right side
        // (the vertical post is implied to be off-screen).
        Rectangle {
            id: beam
            width: parent.width * 0.72
            height: 16
            radius: 2
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 28
            color: scene.creamColor

            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                color: "transparent"
                border.color: scene.creamShade
                border.width: 1
                radius: 1
            }
        }

        // Rope + hanged man, swinging as one around the knot on the beam.
        Item {
            id: pendulum
            width: figure.width
            height: rope.height + figure.height
            x: scene.attachX - width / 2
            y: scene.attachY
            transformOrigin: Item.Top
            rotation: scene.angle * 180 / Math.PI

            Rectangle {
                id: rope
                width: 3
                height: 46
                color: scene.creamColor
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
            }

            Image {
                id: figure
                source: "../images/hanged_man.png"
                anchors.top: rope.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                fillMode: Image.PreserveAspectFit
                height: Math.min(scene.height * 0.62, 190)
                width: height * (implicitWidth / Math.max(implicitHeight, 1))
                smooth: true
                transformOrigin: Item.Top
                rotation: scene.twist * 180 / Math.PI
            }
        }

        // Frame-synced integration, sub-stepped so fast spins stay stable.
        FrameAnimation {
            running: true
            onTriggered: {
                if (scene.dragging) {
                    return
                }
                var dt = Math.min(frameTime, 0.05)
                var steps = 4
                var h = dt / steps
                for (var i = 0; i < steps; ++i) {
                    scene.integrate(h)
                }
                // Fades once the cursor stops moving or leaves.
                scene.hoverTorque *= 0.88
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true

            property real lastDragMs: 0

            onPressed: (ev) => {
                var dx = ev.x - scene.bobX()
                var dy = ev.y - scene.bobY()
                if (dx * dx + dy * dy < 95 * 95) {
                    scene.dragging = true
                    lastDragMs = Date.now()
                    scene.angVel = 0
                }
            }

            onReleased: {
                // Let go and it keeps whatever speed you threw it with.
                scene.dragging = false
            }

            onExited: scene.hoverTorque = 0

            onPositionChanged: (ev) => {
                if (scene.dragging) {
                    var target = Math.atan2(ev.x - scene.attachX, ev.y - scene.attachY)
                    var d = target - scene.angle
                    while (d > Math.PI) d -= 2 * Math.PI
                    while (d < -Math.PI) d += 2 * Math.PI

                    var now = Date.now()
                    var dtMs = Math.max(8, now - lastDragMs)
                    lastDragMs = now
                    scene.angVel = Math.max(-scene.maxAngVel,
                                            Math.min(scene.maxAngVel, d / (dtMs / 1000)))
                    scene.angle = target
                    return
                }

                // Not dragging: brushing past nudges it, like catching it in passing.
                var bx = ev.x - scene.bobX()
                var by = ev.y - scene.bobY()
                var dist = Math.sqrt(bx * bx + by * by)
                if (dist < 85 && dist > 1) {
                    var strength = (85 - dist) / 85
                    scene.hoverTorque = (bx < 0 ? 1 : -1) * strength * 3.5
                } else {
                    scene.hoverTorque = 0
                }
            }

            onClicked: (ev) => {
                var now = Date.now()
                var rapid = (now - scene.lastClickMs) < 320
                scene.lastClickMs = now

                // Shove away from the side you hit. Clicks land in the same
                // direction each time, so hammering one side stacks energy
                // past loopSpeed and the body goes right over the beam.
                var dir = (ev.x < scene.attachX) ? 1 : -1
                var impulse = rapid ? scene.loopSpeed * 0.95 : scene.loopSpeed * 0.48
                scene.angVel = Math.max(-scene.maxAngVel,
                                        Math.min(scene.maxAngVel, scene.angVel + dir * impulse))
                scene.twistVel += dir * 2.0
            }
        }
    }
}
