pragma Singleton

pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property int cacheConfigVersion: 1

    readonly property bool isGreeterMode: Quickshell.env("DMS_RUN_GREETER") === "1" || Quickshell.env("DMS_RUN_GREETER") === "true"

    readonly property string _stateUrl: StandardPaths.writableLocation(StandardPaths.GenericCacheLocation)
    readonly property string _stateDir: Paths.strip(_stateUrl)

    property bool _loading: false

    property string wallpaperLastPath: ""
    property string profileLastPath: ""

    Component.onCompleted: {
        if (!isGreeterMode) {
            loadCache()
        }
    }

    function loadCache() {
        _loading = true
        parseCache(cacheFile.text())
        _loading = false
    }

    function parseCache(content) {
        _loading = true
        try {
            if (content && content.trim()) {
                const cache = JSON.parse(content)

                wallpaperLastPath = cache.wallpaperLastPath !== undefined ? cache.wallpaperLastPath : ""
                profileLastPath = cache.profileLastPath !== undefined ? cache.profileLastPath : ""

                if (cache.configVersion === undefined) {
                    migrateFromUndefinedToV1(cache)
                    cleanupUnusedKeys()
                    saveCache()
                }
            }
        } catch (e) {
            console.warn("CacheData: Failed to parse cache:", e.message)
        } finally {
            _loading = false
        }
    }

    function saveCache() {
        if (_loading)
            return
        cacheFile.setText(JSON.stringify({
                                             "wallpaperLastPath": wallpaperLastPath,
                                             "profileLastPath": profileLastPath,
                                             "configVersion": cacheConfigVersion
                                         }, null, 2))
    }

    function migrateFromUndefinedToV1(cache) {
        console.log("CacheData: Migrating configuration from undefined to version 1")
    }

    function cleanupUnusedKeys() {
        const validKeys = [
            "wallpaperLastPath",
            "profileLastPath",
            "configVersion"
        ]

        try {
            const content = cacheFile.text()
            if (!content || !content.trim()) return

            const cache = JSON.parse(content)
            let needsSave = false

            for (const key in cache) {
                if (!validKeys.includes(key)) {
                    console.log("CacheData: Removing unused key:", key)
                    delete cache[key]
                    needsSave = true
                }
            }

            if (needsSave) {
                cacheFile.setText(JSON.stringify(cache, null, 2))
            }
        } catch (e) {
            console.warn("CacheData: Failed to cleanup unused keys:", e.message)
        }
    }

    FileView {
        id: cacheFile

        path: isGreeterMode ? "" : _stateDir + "/DankMaterialShell/cache.json"
        blockLoading: true
        blockWrites: true
        atomicWrites: true
        watchChanges: !isGreeterMode
        onLoaded: {
            if (!isGreeterMode) {
                parseCache(cacheFile.text())
            }
        }
        onLoadFailed: error => {
            if (!isGreeterMode) {
                console.log("CacheData: No cache file found, starting fresh")
            }
        }
    }
}
