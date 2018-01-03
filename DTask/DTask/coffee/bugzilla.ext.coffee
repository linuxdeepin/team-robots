port = chrome.runtime.connect({name:"dataconnect"})

dtaskUrl = ""
linksUrl = ""
bugzDefaultLinksUrl = ""
createTowerUrl = ""
getProductUrl = ""
getProjectIdUrl = ""

todolistName = "从Bugzilla创建的bug"
params = $.parseParams(location.search.substr(1))
bugzId = params["id"]
bugzTitle = $("#short_desc_nonedit_display").html()
#product = $("#field_container_product").text()
product = ""

params = $.parseParams(location.search.substr(1))
bugzillaId = params["id"]
towerToken = $.cookie 'Tower-Token'
towerCsrf = $.cookie 'Tower-CSRF-Token'


port.onMessage.addListener((msg) ->
    switch msg.type
        when "bugz_open_tower_login_tab_result"
            console.log("open tower login tab")
            #console.log("msg : " + msg.data.msg)

        when "query_dtask_url_result"
            dtaskUrl = msg.url
            initUrls()
            initCurrentBugzInfo()
)

getDTaskUrl = ()->
    port.postMessage(
        type: "query_dtask_url"
    )

loginToTower = () ->
    port.postMessage(
        type:"bugz_open_tower_login_tab"

    )

addLinkingGif = () ->
    gif = $(document.createElement("img"))
    gif.attr(
        src:chrome.extension.getURL("images/loading.gif")
    )
    gif.css(
        height:"20px"
        width: "20px"
    )
    linkDiv.html("")
    linkDiv.append(gif)


createTowerAction = () ->

    if not towerToken and not towerCsrf
        loginToTower()
    else
        addLinkingGif()
        $.ajax({url:bugzDefaultLinksUrl, dataType:"json", success: initBugzProductDefaultLinks})


createTodolist = (projectGuid) ->
    $.ajax(
        url: "#{dtaskUrl}/services/tower/projects/#{projectGuid}/todolists"
        type:"POST"
        dataType:"json"
        headers:
            "Tower-Token":towerToken.replace(/ /g, '+')
            "Tower-CSRF-token":towerCsrf.replace(/ /g, '+')
        data:
            "title": todolistName
        success:(data)->
            if not data.error
                console.log("create todolist successfully")
                console.log(data)
                todolistGuid = data.result.guid
                sendCreateTowerTodoRequest(todolistGuid)
            else
                console.log("create tower failed")
                console.log(data.error_message)
                alert("创建清单失败 #{data.error_message}")
    )


sendCreateTowerTodoRequest = (guid)->
    console.log("creating tower ...")
    $.ajax(
        url:"#{dtaskUrl}/services/tower/import/bugzilla_bug"
        type:"PUT"
        dataType:"json"
        headers:
            "Tower-Token":towerToken.replace(/ /g, '+')
            "Tower-CSRF-token":towerCsrf.replace(/ /g, '+')
        data:
            "bug_id":bugzId
            "todolist_guid":guid
            "bug_titile":bugzTitle
        success:(data)->
            if not data.error
                console.log("create tower successfully")
                console.log(data)
                location.reload()
            else
                console.log("create tower failed")
                console.log(data.error_message)
                alert("创建失败 #{data.error_message}")
    )


linksHandle = (data) ->
    linkDiv.html("")
    if data.result == null || data.result.length == 0
        link = $(document.createElement("a"))
        link.attr({
            "id":"createTaskBtn"
            "href":"javascript:void(0)",
        })
        link.click(createTowerAction)
        link.text("创建讨论")
        linkDiv.append(link)
    else
        tower_todo = data.result[0]
        link = $(document.createElement("a"))
        $.ajax({url:"#{getProjectIdUrl}/#{tower_todo}", dataType: "json", success: (data) ->
            link.attr({
                "href":"https://tower.im/projects/#{data.result}/todos/" + tower_todo
                "target":"_blank"
            })
            link.text("查看tower")
            linkDiv.append(link)
        })


getProductBack = (data)->
    product = data.result.product


linkDiv = $(document.createElement("div"))
$("#summary_alias_container").after(linkDiv)
$("#summary_alias_container").css("display", "inline")
linkDiv.css(
    display : "inline"
    "margin-left": "20px"
)


initBugzProductDefaultLinks = (data) ->
    if not data.error
        bugzDefaultLinks = data.links
        projectGuid = bugzDefaultLinks[product]

        # linked with tower project
        if projectGuid
            getTodolistGuid(projectGuid)

        # not linked, skip to choose tower project
        else
            titile = $("#short_desc_nonedit_display").html()
            url = "#{createTowerUrl}?id=#{bugzillaId}&title=#{titile}&tt=#{$.cookie('Tower-Token').replace(/ /g, '%2B')}&csrf=#{$.cookie('Tower-CSRF-Token').replace(/ /g, '%2B')}"
            window.location = url
    else
        alert("获取默认项目失败：#{data.err_msg}")


getTodolistGuid = (projectGuid) ->
    $.ajax(
        url: "#{dtaskUrl}/services/tower/projects/#{projectGuid}/todolists"
        dataType:"json"
        headers:
            "Tower-Token":towerToken.replace(/ /g, '+')
            "Tower-CSRF-token":towerCsrf.replace(/ /g, '+')
        success:(data)->
            if not data.error
                todolistGuid = ""
                for item in data.result
                    if item.name == todolistName
                        todolistGuid = item.guid

                if todolistGuid == ""
                    # need to create todolist
                    #console.log("creating todolist ...")
                    createTodolist(projectGuid)
                else
                    sendCreateTowerTodoRequest(todolistGuid)
    )

initUrls = ()->
    linksUrl = "#{dtaskUrl}/links"
    bugzDefaultLinksUrl = "#{dtaskUrl}/plugin/services/bugz_default_links"
    createTowerUrl = "#{dtaskUrl}/plugin/static/create_tower.html"
    getProductUrl = "#{dtaskUrl}/services/bugzilla/bug"
    getProjectIdUrl = "#{dtaskUrl}/services/tower/todo"

handleAjaxError = (request, msg, e)->
    alert(msg)

initCurrentBugzInfo = ()->
    $.ajax({url:linksUrl, dataType:"json", data:{"bugzilla":bugzillaId, "tower_todo":"-"}, success: linksHandle})
    $.ajax({url:"#{getProductUrl}/#{bugzillaId}", dataType:"json", success: getProductBack, error: handleAjaxError})

getDTaskUrl()
