import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

SettingsPage {
    title: "Wallpaper"
    subtitle: "hexin paints its own background layer — the bundled picture, one of yours, or nothing."

    SettingRow {
        title: "Style"
        description: "Default: the picture shipped with hexin. Image: a picture you choose. None: hide the layer so hyprpaper/swww shows through."

        Segmented {
            options: [
                {
                    label: "Default",
                    value: "default"
                },
                {
                    label: "Image",
                    value: "image"
                },
                {
                    label: "None",
                    value: "none"
                }
            ]
            current: Config.wallpaper.type
            onSelected: v => {
                Config.wallpaper.type = v
                Theme.requestMatugen(true)
            }
        }
    }

    SectionLabel {
        text: "Picker"
    }

    SettingRow {
        title: "Folder"
        description: "Folder the wallpaper picker (SUPER + W) lists. `~` is expanded to your home directory."

        Input {
            implicitWidth: 360
            text: Config.wallpaper.folder
            placeholder: "~/Pictures/Wallpapers"
            onCommitted: v => Config.wallpaper.folder = v
        }
    }

    Card {
        Layout.fillWidth: true
        spacing: 4

        Txt {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: Theme.subtext
            text: "Press SUPER + W (or run `qs ipc -c hexin call panels toggle wallpaper`) to pick a wallpaper from that folder. Picking one sets the style to Image below and applies it instantly."
        }
    }

    SectionLabel {
        text: "Image"
    }

    SettingRow {
        title: "Image path"
        description: "Absolute path to a picture, e.g. /home/you/Pictures/wall.png"

        Input {
            implicitWidth: 360
            text: Config.wallpaper.image
            valid: text === "" || text.startsWith("/")
            onCommitted: v => {
                Config.wallpaper.image = v
                Theme.requestMatugen(true)
            }
        }
    }
    SettingRow {
        title: "Dim"
        description: "Darken the picture so the bar and panels stay readable."

        ValueSlider {
            from: 0
            to: 0.8
            step: 0.05
            decimals: 2
            value: Config.wallpaper.dim
            onMoved: v => Config.wallpaper.dim = v
        }
    }

    SectionLabel {
        text: "Tips"
    }

    Card {
        Layout.fillWidth: true
        spacing: 4

        Txt {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: Theme.subtext
            text: "Set a folder of pictures as a slideshow with an external daemon (swww or hyprpaper) and choose “None” here — the image path above is only used by hexin's own Image mode."
        }
    }
}
