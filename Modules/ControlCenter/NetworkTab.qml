import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.ControlCenter.Network

Item {
    id: networkTab

    property var wifiPasswordModalRef: wifiPasswordModal
    property var networkInfoModalRef: networkInfoModal

    property var sortedWifiNetworks: {
        if (!NetworkService.wifiAvailable || !NetworkService.wifiEnabled) {
            return []
        }

        var allNetworks = NetworkService.wifiNetworks
        var savedNetworks = NetworkService.savedWifiNetworks
        var currentSSID = NetworkService.currentWifiSSID
        var signalStrength = NetworkService.wifiSignalStrength
        var refreshTrigger = forceRefresh

        // Force recalculation
        var networks = [...allNetworks]

        networks.forEach(function (network) {
            network.connected = (network.ssid === currentSSID)
            network.saved = savedNetworks.some(function (saved) {
                return saved.ssid === network.ssid
            })
            if (network.connected && signalStrength) {
                network.signalStrength = signalStrength
            }
        })

        networks.sort(function (a, b) {
            if (a.connected && !b.connected)
                return -1
            if (!a.connected && b.connected)
                return 1
            return b.signal - a.signal
        })

        return networks
    }

    property int forceRefresh: 0

    Connections {
        target: NetworkService
        function onNetworksUpdated() {
            forceRefresh++
        }
    }

    Component.onCompleted: {
        NetworkService.addRef()
        NetworkService.autoRefreshEnabled = true
        if (NetworkService.wifiEnabled)
            NetworkService.scanWifi()
        wifiMonitorTimer.start()
    }

    Component.onDestruction: {
        NetworkService.removeRef()
        NetworkService.autoRefreshEnabled = false
    }

    Row {
        anchors.fill: parent
        spacing: Theme.spacingM

        Column {
            width: (parent.width - Theme.spacingM) / 2
            height: parent.height
            spacing: Theme.spacingS

            Flickable {
                width: parent.width
                height: parent.height - 30
                clip: true
                contentWidth: width
                contentHeight: wifiContent.height
                boundsBehavior: Flickable.DragAndOvershootBounds
                // Qt 6.9+ scrolling: flickDeceleration/maximumFlickVelocity only affect touch now
                flickDeceleration: 1500
                maximumFlickVelocity: 2000

                // Custom wheel handler for Qt 6.9+ responsive mouse wheel scrolling
                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => {
                        let delta = event.pixelDelta.y
                            !== 0 ? event.pixelDelta.y * 1.8 : event.angleDelta.y / 120 * 60
                        let newY = parent.contentY - delta
                        newY = Math.max(
                            0, Math.min(parent.contentHeight - parent.height, newY))
                        parent.contentY = newY
                        event.accepted = true
                    }
                }

                Column {
                    id: wifiContent
                    width: parent.width
                    spacing: Theme.spacingM

                    WiFiCard {
                        refreshTimer: refreshTimer
                    }
                }

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }
            }
        }

        Column {
            width: (parent.width - Theme.spacingM) / 2
            height: parent.height
            spacing: Theme.spacingS

            Flickable {
                width: parent.width
                height: parent.height - 30
                clip: true
                contentWidth: width
                contentHeight: ethernetContent.height
                boundsBehavior: Flickable.StopAtBounds
                // Qt 6.9+ scrolling: flickDeceleration/maximumFlickVelocity only affect touch now
                flickDeceleration: 1500
                maximumFlickVelocity: 2000

                // Custom wheel handler for Qt 6.9+ responsive mouse wheel scrolling
                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => {
                        let delta = event.pixelDelta.y
                            !== 0 ? event.pixelDelta.y * 1.8 : event.angleDelta.y / 120 * 60
                        let newY = parent.contentY - delta
                        newY = Math.max(
                            0, Math.min(parent.contentHeight - parent.height, newY))
                        parent.contentY = newY
                        event.accepted = true
                    }
                }

                Column {
                    id: ethernetContent
                    width: parent.width
                    spacing: Theme.spacingM

                    EthernetCard {}
                }

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }
            }
        }
    }

    Rectangle {
        anchors.top: parent.top
        anchors.topMargin: 100
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        color: "transparent"
        visible: !NetworkService.wifiEnabled

        Column {
            anchors.centerIn: parent
            spacing: Theme.spacingM

            DankIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: "wifi_off"
                size: 48
                color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g,
                    Theme.surfaceText.b, 0.3)
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "WiFi is turned off"
                font.pixelSize: Theme.fontSizeLarge
                color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g,
                    Theme.surfaceText.b, 0.6)
                font.weight: Font.Medium
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Turn on WiFi to see networks"
                font.pixelSize: Theme.fontSizeMedium
                color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g,
                    Theme.surfaceText.b, 0.4)
            }
        }
    }

    WiFiNetworksList {
        wifiContextMenuWindow: wifiContextMenuWindow
        sortedWifiNetworks: networkTab.sortedWifiNetworks
        wifiPasswordModalRef: networkTab.wifiPasswordModalRef
    }

    Timer {
        id: refreshTimer
        interval: 2000
        running: visible && refreshTimer.triggered
        property bool triggered: false
        onTriggered: {
            NetworkService.refreshNetworkStatus()
            if (NetworkService.wifiEnabled && !NetworkService.isScanning) {
                NetworkService.scanWifi()
            }
            triggered = false
        }
    }

    Connections {
        target: NetworkService
        function onWifiEnabledChanged() {
            if (NetworkService.wifiEnabled && visible) {
                wifiScanDelayTimer.start()
                wifiMonitorTimer.start()
            } else {
                NetworkService.currentWifiSSID = ""
                NetworkService.wifiSignalStrength = "excellent"
                NetworkService.wifiNetworks = []
                NetworkService.savedWifiNetworks = []
                NetworkService.connectionStatus = ""
                NetworkService.connectingSSID = ""
                NetworkService.isScanning = false
                NetworkService.refreshNetworkStatus()
                wifiMonitorTimer.stop()
            }
        }
    }

    Timer {
        id: wifiScanDelayTimer
        interval: 1500
        running: false
        repeat: false
        onTriggered: {
            if (NetworkService.wifiEnabled && visible) {
                if (!NetworkService.isScanning) {
                    NetworkService.scanWifi()
                } else {
                    wifiRetryTimer.start()
                }
            }
        }
    }

    Timer {
        id: wifiRetryTimer
        interval: 2000
        running: false
        repeat: false
        onTriggered: {
            if (NetworkService.wifiEnabled && visible
                && NetworkService.wifiNetworks.length === 0) {
                if (!NetworkService.isScanning) {
                    NetworkService.scanWifi()
                }
            }
        }
    }

    Timer {
        id: wifiMonitorTimer
        interval: 8000 // Check every 8 seconds
        running: false
        repeat: true
        onTriggered: {
            if (!visible || !NetworkService.wifiEnabled) {
                running = false
                return
            }

            var shouldScan = false
            var reason = ""

            if (NetworkService.networkStatus !== "wifi") {
                shouldScan = true
                reason = "not connected to WiFi"
            } else if (NetworkService.wifiNetworks.length === 0) {
                shouldScan = true
                reason = "no networks cached"
            }

            if (shouldScan && !NetworkService.isScanning) {
                NetworkService.scanWifi()
            }
        }
    }

    onVisibleChanged: {
        if (visible && NetworkService.wifiEnabled) {
            wifiMonitorTimer.start()
        } else {
            wifiMonitorTimer.stop()
        }
    }

    WiFiContextMenu {
        id: wifiContextMenuWindow
        parentItem: networkTab
        wifiPasswordModalRef: networkTab.wifiPasswordModalRef
        networkInfoModalRef: networkTab.networkInfoModalRef
    }

    MouseArea {
        anchors.fill: parent
        visible: wifiContextMenuWindow.visible
        onClicked: {
            wifiContextMenuWindow.hide()
        }

        MouseArea {
            x: wifiContextMenuWindow.x
            y: wifiContextMenuWindow.y
            width: wifiContextMenuWindow.width
            height: wifiContextMenuWindow.height
            onClicked: {

            }
        }
    }
}