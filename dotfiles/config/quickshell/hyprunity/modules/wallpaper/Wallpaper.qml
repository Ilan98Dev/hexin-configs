// =====================================================================
//  Wallpaper.qml — hyprunity's own wallpaper surface.
//
//  A full-screen layer surface on WlrLayer.Background, one per monitor:
//    * "default" — the picture bundled with this config (assets/wallpaper.jpg)
//    * "image"   — a picture you pick, cropped to fill, softened by a scrim
//    * "none"    — this surface disappears entirely, so an external
//                  wallpaper daemon (hyprpaper / swww) is visible again.
//
//  Changing the picture dissolves rather than blinking: two stacked
//  Images let the newly picked one fade in over the one already on
//  screen. The timing follows Settings ▸ Appearance ▸ Animations
//  (off = instant).
// =====================================================================
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config

PanelWindow {
    id: bg

    required property var modelData
    screen: modelData

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"

    // Do NOT set exclusiveZone on this surface. Setting it forces the
    // surface's exclusionMode to Normal, which makes the compositor lay the
    // wallpaper out inside the "usable area" (output minus the bar's reserved
    // strip). The wallpaper then starts below the bar and the floating bar's
    // transparent margin reveals the compositor's plain background instead of
    // the wallpaper, so the bar does not look like it is floating.
    // Ignore keeps this surface covering the whole output; the compositor will
    // still honour the bar's own exclusive zone for real windows.
    exclusionMode: ExclusionMode.Ignore
    focusable: false

    visible: Config.wallpaper.type !== "none"

    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "qs-wallpaper"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    readonly property bool showImage: Config.wallpaper.type === "default" || (Config.wallpaper.type === "image" && Config.wallpaper.image && String(Config.wallpaper.image).length > 0)

    // The picture that should be on screen right now ("" when not in image
    // mode). A change here is what starts a dissolve.
    readonly property string wanted: {
        if (Config.wallpaper.type === "default")
            return Config.defaultWallpaper.toString();
        if (bg.showImage) {
            const p = Config.wallpaper.image || "";
            if (p === "") return "";
            if (String(p).indexOf("://") >= 0) return String(p);
            return "file://" + String(p);
        }
        return "";
    }

    // When Auto (Matugen) is on, regenerate the palette as the picture changes.
    // Wallpaper is always mounted (one per monitor), so this is the reliable trigger.
    onWantedChanged: {
        if (Config.appearance.preset === "Auto (Matugen)" && bg.wanted.length)
            Theme.requestMatugen(true);
    }

    // A wallpaper change is worth twice the shell's usual animation time: a
    // dissolve reads better a little slower. Theme.anim is 0 when animations
    // are switched off, which makes every change instant.
    readonly property int fade: Math.round(Theme.anim * 2)

    // base colour
    Rectangle {
        anchors.fill: parent
        color: Theme.base
    }

    // picture wallpaper
    Item {
        id: imageLayer

        // Which picture should be showing. Fed from the config, and the
        // only thing that starts a dissolve.
        property string wanted: bg.wanted

        // The picture on screen, and the one loading up behind it. Each is
        // either imgA or imgB; they swap roles on every change.
        property var shown: null
        property var pending: null

        anchors.fill: parent
        visible: opacity > 0 || bg.showImage
        opacity: bg.showImage ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: bg.fade
                easing.type: Easing.InOutQuad
            }
        }

        onWantedChanged: show(wanted)
        Component.onCompleted: show(wanted)

        // Dissolve `path` in. The idle Image takes the new picture and is
        // brought to the front once it has actually decoded, so the change
        // never flashes an empty layer.
        function show(path) {
            if (path === "")
                return;
            if (shown !== null && shown.path === path)
                return;                                    // already on screen

            const img = (shown === imgA) ? imgB : imgA;
            pending = img;
            img.opacity = 0;                               // sits behind `shown`, so this is unseen
            if (img.path === path)
                img.path = "";                             // force a fresh load so it dissolves too
            img.path = path;
        }

        function reveal(img) {
            const prev = shown;
            if (prev !== null && prev !== img)
                prev.z = 1;
            img.z = 2;                                     // the newest picture is on top
            img.opacity = 0;
            shown = img;
            pending = null;
            if (bg.fade <= 0) {
                img.opacity = 1;
                return;
            }
            revealAnim.target = img;
            revealAnim.restart();
        }

        // Called whenever a loading picture changes status. Only the picture
        // that is actually pending may finish a dissolve, so a slow decode
        // can never pull an older picture back to the front.
        function settle(img) {
            if (img.status === Image.Ready) {
                reveal(img);
            } else if (img.status === Image.Error) {
                // Keep whatever is already on screen instead of fading to an
                // empty layer; clear `pending` so the next pick still works.
                console.warn("wallpaper: cannot load " + img.path);
                img.path = "";
                pending = null;
            }
        }

        // Fades whichever picture was just revealed up to full strength.
        NumberAnimation {
            id: revealAnim
            property: "opacity"
            to: 1
            duration: bg.fade
            easing.type: Easing.OutCubic
        }

        // The two pictures, sharing the layer's z-stacking so the scrim
        // below always stays on top of both.
        Item {
            id: pics
            anchors.fill: parent

            Image {
                id: imgA
                property string path: ""

                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                smooth: true
                asynchronous: true
                cache: true
                opacity: 0
                z: 1
                source: path

                onStatusChanged: if (imageLayer.pending === imgA) imageLayer.settle(imgA)
            }

            Image {
                id: imgB
                property string path: ""

                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                smooth: true
                asynchronous: true
                cache: true
                opacity: 0
                z: 1
                source: path

                onStatusChanged: if (imageLayer.pending === imgB) imageLayer.settle(imgB)
            }
        }

        // scrim so the bar and panels stay readable over bright pictures
        Rectangle {
            anchors.fill: parent
            visible: bg.showImage
            color: Qt.rgba(0.05, 0.04, 0.09, Config.wallpaper.dim)
        }
    }
}
