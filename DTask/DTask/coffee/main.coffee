dtaskUrl = ""
error = false

port = chrome.runtime.connect({name:"dataconnect"})

port.onDisconnect.addListener((msg)->
    console.log("port disconnect ...")
    port = null
)

port.onMessage.addListener((msg)->
    switch msg.type
        when "query_dtask_url_result"
            dtaskUrl = msg.url
            console.log(dtaskUrl)
            dtaskUpdate()
)

checkTodoStatus = (todoGroup)->
    $.ajax(
        type: 'POST'
        url: "#{dtaskUrl}/services/for_browser_plugin"
        dataType:"json"
        contentType: "application/json; charset=utf-8"
        data: JSON.stringify
            todo_guids: todoGroup
        success: (data)->
            checkTodoStatusResult(data)
        error: (req, msg, e)->
            console.log("check links request error: ", msg)
            error = true
    )


getTowerDetailInfo = (todoGuid, callback)->
    $.ajax(
        url: "#{dtaskUrl}/services/tower/todos/#{todoGuid}"
        headers:
            "Tower-Token":towerToken
        dataType:"json"
        success: (data)->
            callback(data, todoGuid)
        error: (req, msg, e)->
            console.log("get tower detail error: ", msg)
            error = true
    )


renderTodoStatusLabel = (todoGuid, bugzId)->
    # add label
    $(".todo").each((i, e)->
        if todoGuid == e.getAttribute("data-guid") and $(e).find(".dtask-label").length == 0
            $(e).attr
              "data-bugzilla-id": bugzId
            bugzUrl = "https://bugzilla.deepin.io/show_bug.cgi?id=#{bugzId}"
            bugzLink = $(document.createElement("a"))
            bugzLink.attr(
                href: bugzUrl
                target: "_blank"
                title: "Bugzilla: " + bugzId
            )
            bugzLink.text(" Bugzilla ")
            bugzLink.addClass("bugzilla-link")
            bugzLink.addClass("dtask-label")
            bugzLink.addClass("label no-assign")
            $(e).find(".todo-assign-due").after(bugzLink)
    )


checkTodoStatusResult = (data)->
  for todo in data.result
    do (todo) ->
      renderTodoStatusLabel(todo.towerGuid, todo.bugzillaId)
      renderTodoStatusIcons(data, todo.towerGuid)


dtaskUpdate = ->
    todoGroup = []
    $(".todo").each((i, e)->
        if not $(e).find(".dtask-marker-label-for-gerrit").length
            todoGuid = $(e).attr("data-guid")
            todoGroup.push(todoGuid)
            $(e).append(getMarkerLabel())
    )
    if todoGroup.length
        checkTodoStatus(todoGroup)

    hackTaskCount()
    hackSlidebarMenu()


getMarkerLabel = ()->
    label = $(document.createElement("input"))
    label.attr(
        type: "hidden"
    )
    label.addClass("dtask-marker-label-for-gerrit")
    return label


images = {}
imageFactory = (src)->
    cached = images[name]
    if !cached
        images[src] = $(document.createElement("img"))
        cached = images[src]
        cached.attr("src", "#{src}")
        #cached.addClass("avatar")
    return cached.clone()

renderIconsContainer = (icons, parent)->
    for status in icons
        link = $(document.createElement("a"))
        if status.link
            link.attr(
                "title": status.title
                "href": status.link
                "target": "_blank"
            )
        else
            link.attr(
                "title": status.title
                "href": "javascript: void(0)"
            )

        link.append(imageFactory(status.image))

        parent.append(link)

renderTodoStatusIcons = (data, todoGuid)->
    el = $(".todo[data-guid=#{todoGuid}]")
    el.find(".dtask-icons").remove()
    data?.result?.status_icons?.forEach((c)->
        container = $(document.createElement("span"))
        groupName = c.group
        renderIconsContainer(c.icons, container)
        container.html("&nbsp" + container.html() + "&nbsp")
        container.addClass("dtask-icons")
        el.find(".todo-content").prepend(container)
    )


hackTaskCount = ->
    hackingDayProjectGuid = "792c5b3e3279431b9ca757dee0219d8a"
    if not location.href.match(hackingDayProjectGuid)
        s = $(".todos-uncompleted > .todo").size()
        if s != 0
            $("#link-feedback").attr("title", "当前页面未完成数:#{s}")
        else
            $("#link-feedback").attr("title", "")


hackSlidebarMenu = ()->

    menuEL = $(".detail-actions")
    if menuEL.find(".dtask-hide-comment-slidebar").length
        return ""
    # hide comments
    hideCommentsDivEL = $(document.createElement("div"))
    hideCommentsDivEL.addClass("item")

    hideCommentsAEL = $(document.createElement("A"))
    hideCommentsAEL.addClass("detail-action")
    hideCommentsAEL.addClass("detail-action-edit")
    hideCommentsAEL.addClass("dtask-hide-comment-slidebar")
    hideStr = "隐藏评论"
    showStr = "显示评论"
    hideCommentsAEL.text(hideStr)
    hideCommentsAEL.click(()->
        #$(".comments.streams").remove()
        if $(".comments.streams").css("display") == "block"
            $(".comments.streams").css(
                display: "none"
            )
            hideCommentsAEL.text(showStr)
        else
            $(".comments.streams").css(
                display: "block"
            )
            hideCommentsAEL.text(hideStr)
    )
    hideCommentsAEL.attr(
        href: "javascript:;"
    )

    hideCommentsDivEL.append(hideCommentsAEL)

    menuEL.append(hideCommentsDivEL)


# start
port.postMessage(
    type: "query_dtask_url"
)

# tmp
dtaskUpdateIntvl = setInterval(dtaskUpdate, 1000)

$(document).ready ()->
  #$(".todo-rest").click () ->
  $(".simple-checkbox:not(.checked)").click () ->
    if not $.cookie "bugzilla_token"
      port.postMessage
        type: "open_bugz_login_tab"

    self = this
    d = setInterval(
      ()->
        bugzillaToken = $.cookie "bugzilla_token"
        if bugzillaToken
          bugId = $(self).closest("li.todo").attr("data-bugzilla-id")
          if not bugId
            window.clearInterval(d)
            return
          $.ajax
            type: "POST"
            url: "#{dtaskUrl}/services/bugzilla/close"
            dataType:"json"
            headers:
              "token": bugzillaToken
            data:
              bug_id: bugId
            success: (data) ->
              if not data.error
                port.postMessage
                  type: "notificate"
                  title: "关闭完成"
                  message: "对应的Bugzilla已关闭"
              else
                port.postMessage
                  type: "notificate"
                  title: "关闭失败"
                  message: "对应的Bugzilla未关闭"
            error: () ->
              port.postMessage
                type: "notificate"
                title: "关闭失败"
                message: "对应的Bugzilla未关闭"
          window.clearInterval(d)
      1000
    )
