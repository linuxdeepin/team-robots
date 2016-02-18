dtaskUrl = "https://tools.deepin.io/dtask"
hackingDayUrl = "https://private.deepin.io"
dtaskToolsUrl = "https://tools.deepin.io/dtask"
towerLoginUrl = "#{dtaskToolsUrl}/plugin/static/tower_login.html"
towerTokenCookieDomain ="https://bugzilla.deepin.io"

ports = []
lastBugzTabId = 0
cache = {}

console.log("init background...")

method=
    "query_dtask_url": (id, port)->
        port.postMessage(
            type: "query_dtask_url_result"
            url: dtaskUrl
        )

    "query_dtask_tools_url": (id, port)->
        port.postMessage(
            type: "query_dtask_tools_url_result"
            url: dtaskToolsUrl
        )

    "query_hacking_day_url": (id, port)->
        port.postMessage(
            type: "query_hacking_day_url_result"
            url: hackingDayUrl
        )

    "cache_store": (id, port, data)->
        for k, v of data.cache
            cache[k] = v

        port.postMessage(
            type: "cache_store_result"
            cache: data.cache
        )

    "cache_get": (id, port, data)->
        key = data.key
        value = null

        if cache.hasOwnProperty(key)
            value = cache[key]

        port.postMessage(
            type: "cache_get_result"
            key: key
            value: value
        )

    # ----------- bugzilla ---------- #
    "bugz_open_tower_login_tab":(id, port, msg)->
        tmpId = port.sender.tab?.id
        index = port.sender.tab?.index

        if not tmpId
            lastBugzTabId = tmpId

        if not index
            index = 0

        chrome.tabs.create(
            url:towerLoginUrl
            index: index + 1
        )

        data= {}
        data["msg"] = "open tab normally "
        port.postMessage(
            type:"bugz_open_tower_login_tab_result"
            data:data
        )


    "bugz_store_tower_token":(id, port, msg)->
        token = msg.token
        expires = msg.expires
        console.log("bugz store tower token")
        if token != ""
            # store cookie
            chrome.cookies.set(
                "name":"Tower-Token"
                "url": towerTokenCookieDomain
                "value":token
                "expirationDate":new Date().getTime()/1000 + parseInt(expires)
            )

            if lastBugzTabId
                chrome.tabs.reload(lastBugzTabId)
                chrome.tabs.update(lastBugzTabId, { highlighted:true})

            chrome.tabs.remove(port.sender.tab.id)
    # ----------- bugzilla ---------- #


chrome.runtime.onConnect.addListener((port)->
    console.log("Found an new port", port)
    ports[port.sender.id] = port
    port.onMessage.addListener((msg)->
        msg.id = msg.id || 0
        method[msg.type]?(msg.id, port, msg)
    )
    port.onDisconnect.addListener((p)->
        delete ports[port.sender.id]
    )
)
