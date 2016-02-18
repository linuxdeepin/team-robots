port = chrome.runtime.connect({name:"dataconnect"})

dtaskUrl = ""
loginTowerUrl = ""
setDefaultLinksEL = $("#defaultLinks")

settingDefaultLinksPagesUrl = ""

port.onMessage.addListener((msg) ->
    switch msg.type
        when "query_dtask_tools_url_result"
            console.log("query_dtask_tools_url_result ", msg.url)
            dtaskUrl = msg.url
            initUrls()
            getTowerToken()
)


#setDefaultLinksEL.on("click", getTowerToken)

getDTaskUrl = ()->
    port.postMessage(
        type: "query_dtask_tools_url"
    )

loginToTower = () ->
    port.postMessage(
        type:"bugz_open_tower_login_tab"

    )

initUrls = ()->
    settingDefaultLinksPagesUrl = "#{dtaskUrl}/plugin/static/set_bugz_todolist_links.html"
    loginTowerUrl = "#{dtaskUrl}/plugin/static/tower_login.html"
    dtaskIndexUrl = "#{dtaskUrl}/plugin/pages/index.html"
    $("#about").attr(
        "href": dtaskIndexUrl
    )


getTowerToken = ()->
    console.log("get tower token...")
    chrome.cookies.get({url:"https://bugzilla.deepin.io", name:"Tower-Token"}, (cookie)->
        if not cookie
            console.log("login to tower")
            setDefaultLinksEL.attr(
                target: "_blank"
                href: loginTowerUrl
            )
        else
            towerToken = cookie.value
            setDefaultLinksEL.attr(
                target: "_blank"
                href: "#{settingDefaultLinksPagesUrl}?tt=#{towerToken}"
            )
            console.log("#{settingDefaultLinksPagesUrl}?tt=#{towerToken}")
    )

getDTaskUrl()
