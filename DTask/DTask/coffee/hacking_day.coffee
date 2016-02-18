dtaskUrl = ""
error = false

userGuid = ""
title = ""
userData = {}
groupData = {}

#hack day guid
hackingDayData = {
    project:"792c5b3e3279431b9ca757dee0219d8a",
    uncompleted:"405a6ae12c4a4121a0c6dc23efa459be",
    testRequest:"4e61367839924710948c71425f1c49d4"
    regress: "b25dc4347f46405ba754b6060abeed1e"
}

# hacking day project and todos page url reg
projectsUrlReg = "https://tower.im/projects/#{hackingDayData.project}/?$"
todosUrlReg = "https://tower.im/projects/#{hackingDayData.project}/todos/[0-9a-f]{32}"

COMMENT_TEST_SUCCESS = ":smile: 测试通过咯 :thumbsup:"
COMMENT_TEST_FAILED = ":cold_sweat: 测试失败了 :broken_heart:"
COMMENT_TEST_SUCCESS_DIAG = "真棒! 任务已经移动到回归测试列表咯~~"
COMMENT_TEST_FAILED_DIAG = "记得把测试失败的气球扎破哦~~"

port = chrome.runtime.connect({name:"dataconnect"})

port.onDisconnect.addListener((msg)->
    console.log("port disconnect ...")
    port = null
)


port.onMessage.addListener((msg)->
    switch msg.type
        when "query_hacking_day_url_result"
            dtaskUrl = msg.url
            console.log(dtaskUrl)
            dtaskUpdate()

        when "cache_get_result"
            #console.log(msg)
            switch msg.key
                when "hacking_day_user_data"
                    if msg.value
                        userData = msg.value
                    else
                        getUserData()

                when "hacking_day_group_data"
                    #console.log(msg.value)
                    if msg.value
                        groupData = msg.value
                    else
                        getGroupInfo()

        when "cache_store_result"
            return ""
            #console.log("cache has been stored")
            #console.log("result:", msg)
)


dtaskUpdate = () ->
    # just show in hacking day page
    if location.href.match(projectsUrlReg) or location.href.match(todosUrlReg)
        userGuid = $("#member-guid").val()
        #userGuid = "abcefesafdsaklfdsjieo"
        title = $(".todo .todo-rest")[0]?.textContent

        # just work for special todolist
        uncompletedTodolist = $(".todolist[data-guid=#{hackingDayData.uncompleted}]")
        testingTodolist = $(".todolist[data-guid=#{hackingDayData.testRequest}]")
        regressTodolist = $(".todolist[data-guid=#{hackingDayData.regress}]")

        if location.href.match(projectsUrlReg)
            uncompletedTodolist.find(".todo").each((i, e)->
                if not $(e).find(".dtask-marker-label").length
                    projectGuid = e.getAttribute("data-project-guid")
                    todoGuid = e.getAttribute("data-guid")
                    checkTodoStatus(projectGuid, todoGuid)
                    $(e).append(getMarkerLabel())

                    # debug
                    #console.log("uncompleted: update todo status, guid: " + todoGuid)

            )

            testingTodolist.find(".todo").each((i, e)->
                if not $(e).find(".dtask-marker-label").length
                    projectGuid = e.getAttribute("data-project-guid")
                    todoGuid = e.getAttribute("data-guid")
                    checkTodoStatus(projectGuid, todoGuid)
                    $(e).append(getMarkerLabel())

                    # debug
                    #console.log("testing: update todo status, guid: " + todoGuid)

            )

            regressTodolist.find(".todo").each((i, e)->
                if not $(e).find(".dtask-marker-label").length
                    projectGuid = e.getAttribute("data-project-guid")
                    todoGuid = e.getAttribute("data-guid")
                    checkTodoStatus(projectGuid, todoGuid)
                    $(e).append(getMarkerLabel())

                    # debug
                    #console.log("regress: update todo status, guid: " + todoGuid)
            )

        if location.href.match(todosUrlReg)
            $(".todo").each((i, e)->
                if not $(e).find(".dtask-marker-label").length
                    projectGuid = e.getAttribute("data-project-guid")
                    todoGuid = e.getAttribute("data-guid")
                    checkTodoStatus(projectGuid, todoGuid)
                    $(e).append(getMarkerLabel())

                    # debug
                    #console.log("todo: update todo status, guid: " + todoGuid)
            )

        hackTaskCount()


getMarkerLabel = ()->
    label = $(document.createElement("input"))
    label.attr(
        type: "hidden"
    )
    label.addClass("dtask-marker-label")
    return label

checkTodoStatus = (projectGuid, todoGuid)->
    $.ajax(
        url: "#{dtaskUrl}/hacking_day/mission"
        dataType:"json"
        data:
            todo_guid: todoGuid
            member_guid: userGuid
            todo_title: title
        success: (data)->
            checkTodoStatusResult(data, projectGuid, todoGuid)
        error: (req, msg, e)->
            console.log("get task status request error: ", msg)
            error = true
    )


hackTaskCount = ->
    uncompletedCount = $(".todolist[data-guid=#{hackingDayData.uncompleted}]").find(".todo").size()
    canNotBeToken = $(".todolist[data-guid=#{hackingDayData.uncompleted}]").find(".todo").find(".dtask-take-task-label").size()
    canBeToken = uncompletedCount - canNotBeToken

    testingCount = $(".todolist[data-guid=#{hackingDayData.testRequest}]").find(".todo").size()
    regressCount = $(".todolist[data-guid=#{hackingDayData.regress}]").find(".todo").size()

    titleMsg = """
    任务列表: #{uncompletedCount} 个 ( #{canBeToken} 个可抢)
    测试列表: #{testingCount} 个
    回归测试列表: #{regressCount} 个
    """
    $("#link-feedback").attr("title", titleMsg)


checkTodoStatusResult = (data, projectGuid, todoGuid)->

    #console.log("task status data: ", data)
    renderTakeTaskLabel(data, projectGuid, todoGuid)

    # render test request label and test decision label
    if location.href.match(todosUrlReg)
        currentListUrl = $(".project-info>span>a:last").attr("href")

        # tester decision test result label
        if userData.role?.toLowerCase() == "tester" and currentListUrl.match(hackingDayData.testRequest)
            renderTestDecisionLabel(data, projectGuid, todoGuid)

        # test request label
        if data.result?.can_be_given_up and currentListUrl.match(hackingDayData.uncompleted)
            # and data.result?.status?.toLowerCase() != "testing"
            # show test request
            $.ajax(
                url: "#{dtaskUrl}/hacking_day/testers"
                dataType:"json"
                data:
                    member_guid: userGuid
                success: (data)->
                    getQAsResult(data, projectGuid, todoGuid)
                error: (req, msg, e)->
                    console.log("get QAs request error: ", msg)
                    error = true
            )


getTakeTaskHackJs = (data, projectGuid, todoGuid)->

    hackJs = ""
    if not data.result?.is_grabbed
        commentContent = "<p> :sunglasses: 这一单子我抢啦~~</p>"
        cc = ""
        connGuid = $("#conn-guid").val()

        hackJs += """
        $.ajax({
            url:"https://tower.im/projects/#{projectGuid}/todos/#{todoGuid}/comments",
            data: {
                "completed":false,
                "comment_content": '#{commentContent}',
                "is_html": 1,
                "cc_guids": "#{cc}",
                "conn_guid": "#{connGuid}"
            }
        });
        """

    else if data.result?.can_be_given_up
        # 放弃任务
        reorder = """
        $.ajax({
            url:"https://tower.im/projects/#{projectGuid}/todos/#{todoGuid}/reorder",
            data: {"list_guid":"#{hackingDayData.uncompleted}", "completed":false}
        });
        setTimeout( "window.location.reload()", 1000);
        """

        #\\window.location.reload();

        hackJs += reorder

    return hackJs


takeTaskResult = (data, el)->
    memberNotFoundIdentificatin = "member_guid not found"
    if data.result?.is_success
        comment = " :sunglasses: 这一单子我抢啦~~"
        $(".fake-textarea").click()
        $(".simditor-body").html("<p>#{comment}</p>")
        $(".btn-create-comment").click()

        #alert("抢单成功")
        hackDialogJs = 'simple.dialog.message({content:"抢单成功! 加油!!"})'
        runOnPage(hackDialogJs)

        # only remove dtask-marker-label, can label be update as soon
        $(".todo").find(".dtask-marker-label").remove()

        dtaskUpdate()

    else if data.result?.winner?
        #window.location.reload()
        content = "抢单失败: 任务已被 #{data.result?.winner?.group} 抢啦"
        hackDialogJs = """simple.dialog.confirm({
            content:'#{content}',
            buttons:[{
                text: 'Oh no~~',
                callback: function(e){
                    location.reload()
                    }
                }]
            })"""
        runOnPage(hackDialogJs)

    else if data.error_message? && data.error_message.indexOf(memberNotFoundIdentificatin) > -1
        content = "抢单失败：您不是本次活动的参与者，不能参与抢单"
        hackDialogJs = "simple.dialog.message({content:'#{content}'})"
        runOnPage(hackDialogJs)

    else
        content = "抢单失败: #{data.error_message}"
        hackDialogJs = "simple.dialog.message({content:'#{content}'})"
        runOnPage(hackDialogJs)


giveUpTaskRequest = (todoGuid, el) ->
    $.ajax(
        url: "#{dtaskUrl}/hacking_day/mission/grab"
        type: "DELETE"
        dataType:"json"
        data:
            todo_guid: todoGuid
            member_guid: userGuid
            todo_title: title
        success: (data)->
            giveUpTaskResult(data, el)
        error: (req, msg, e)->
            console.log("give up task request error: ", msg)
            error = true
    )

giveUpTaskResult = (data, el)->
    if data.result?.is_success
        # execute success-js
        content = " :scream: 太难了，我不干了 T_T "
        addTowerComment(content)
        runOnPage(el.attr("success-js"))
        #dtaskUpdate() # reload page in success-js


takeTaskClickEvent = (e)->
    el = $(this)
    todoGuid = e.data.todoGuid
    if el.hasClass("type-error")
        console.log("no permission, can not take task")

    else if el.hasClass("type-take-task")
        takeTaskRequest(todoGuid, el)

    else if el.hasClass("type-give-up")
        if confirm(" 确定要放弃你们的任务吗？")
            giveUpTaskRequest(todoGuid, el)

    else
        console.log("take task click event, but nothing happen")


takeTaskRequest = (todoGuid, el) ->
    $.ajax(
        url: "#{dtaskUrl}/hacking_day/mission/grab"
        type: "POST"
        dataType:"json"
        data:
            todo_guid: todoGuid
            todo_title: title
            member_guid: userGuid
            #member_guid: "7eb8b087d6d247d0b3f86331900e63ed"
        success: (data)->
            if not data.error
                takeTaskResult(data, el)
            else if data.error_message.match("mission grab limit reached")
                text = " >_< &nbsp; 抢单数量已达到你们队伍的上限啦，请先完成或放弃部分任务"
                hackDialogJs = "simple.dialog.message({content:\"#{text}\"})"
                runOnPage(hackDialogJs)
        error: (req, msg, e)->
            console.log("take task request error: ", msg)
            error = true
    )

getTestRequestHackJs = (data, projectGuid, todoGuid)->
    reorder = """
    $.ajax({
        url:"https://tower.im/projects/#{projectGuid}/todos/#{todoGuid}/reorder",
        data: {"list_guid":"#{hackingDayData.testRequest}", "completed":false}
    });
    """

    hackJs = reorder

    return hackJs


genTakeTaskEL = (data, projectGuid, todoGuid)->

    takeTask = $(document.createElement("a"))
    takeTaskHackJs = getTakeTaskHackJs(data, projectGuid, todoGuid)
    takeTask.attr(
        href: "javascript:void(0)"
        #onclick: takeTaskHackJs
        "success-js": takeTaskHackJs
    )

    if data.error or (not data.result?.can_be_grabbed and not data.result?.can_be_given_up and not data.result?.is_grabbed)
        #return null
        takeTask.text("不可抢")
        takeTask.addClass("label assign")
        takeTask.addClass("type-error")
        console.log("error:", data.error_message) if data.error_message?

    else if data.result?.can_be_grabbed
        takeTask.text("立即抢单")
        takeTask.addClass("label no-assign")
        takeTask.addClass("type-take-task")
        takeTask.css(
            "background-color": "#CCFF66"
            "color":"black"
        )

    else if data.result?.can_be_given_up and not location.href.match(projectsUrlReg)
        takeTask.text("放弃任务")
        takeTask.addClass("label no-assign")
        takeTask.css(
            "background-color": "#FF6666"
            "color":"black"
        )
        takeTask.addClass("type-give-up")

    else
        takeTask.text("已被 #{data.result?.winner?.group} 抢啦")
        takeTask.addClass("label assign")
        takeTask.addClass("type-none")
        takeTask.css(
            "background-color": "#CCCC66"
            "color":"black"
        )

    takeTask.addClass("dtask-hd-label")
    takeTask.addClass("dtask-take-task-label")

    takeTask.bind("click", {projectGuid: projectGuid,todoGuid: todoGuid}, takeTaskClickEvent)

    return takeTask


getQAsResult = (data, projectGuid, todoGuid)->
    renderTestRequestLabel(data, projectGuid, todoGuid)


testRequestClickEvent = (e)->

    groupData = e.data.data

    todoGuid = e.data.todoGuid
    $.ajax(
        url: "#{dtaskUrl}/hacking_day/mission/request_test"
        type: "POST"
        dataType:"json"
        data:
            todo_guid: todoGuid
            member_guid: userGuid
            todo_title: title
        success: (rspData)->
            testRequestResult(rspData, groupData, todoGuid)
        error: (req, msg, e)->
            console.log("send test requesting request error: ", msg)
            error = true
    )


testRequestResult = (data, groupData, todoGuid)->
    if data.result
        # comment
        commentContent = "<p> :sunglasses: 请求测试 <br />"
        connGuid = $("#conn-guid").val()
        groupData.result?.testers?.forEach((c)->
            content = "<a href=\"/members/#{c.guid}\" data-mention=\"true\">@#{c.nickname}</a>&nbsp;"
            commentContent += content
            c = $(".member-list input[value=#{c.guid}]")
            c.attr("checked", true)
        )
        commentContent += "</p>"

        addTowerComment(commentContent)

        # dialog tips
        hackDialogJs = """simple.dialog.confirm(
            {content:"太棒了！记得去找评委领气球喔~ ",
            buttons:[{
                text: "知道啦~ ^o^",
                callback: function(e){
                            location.reload()
                        }
                    }
                ]}
            );"""

        reorder = """
        $.ajax({
            url:"https://tower.im/projects/#{hackingDayData.project}/todos/#{todoGuid}/reorder",
            data: {"list_guid":"#{hackingDayData.testRequest}", "completed":false}
        });
        """
        runOnPage(reorder + hackDialogJs)
    else
        console.log("request test result is false", data)


renderTakeTaskLabel = (data, projectGuid, todoGuid)->

    # add label
    e = $(".todo[data-guid=#{todoGuid}]")
    e.find(".dtask-take-task-label").remove()

    currentListUrl = $(".project-info>span>a:last").attr("href")

    if location.href.match(projectsUrlReg) or currentListUrl.match(hackingDayData.uncompleted) or currentListUrl.match(hackingDayData.testRequest) or currentListUrl.match(hackingDayData.regress)

        # skip if current url is project page url and there is not any task with winner
        if location.href.match(projectsUrlReg) and not data.result?.winner?
            return ""

        takeTaskEL = genTakeTaskEL(data, projectGuid, todoGuid)

        if takeTaskEL?
            $(e).find(".todo-detail").append(takeTaskEL)


renderTestDecisionLabel = (data, projectGuid, todoGuid)->
    # add label
    e = $(".todo[data-guid=#{todoGuid}]")
    e.find(".dtask-test-decision-label").remove()

    testSuccessEL = genTestSuccessEL(data, projectGuid, todoGuid)
    testFailedEL = genTestFailedEL(data, projectGuid, todoGuid)

    if testSuccessEL?
        $(e).find(".todo-detail").append(testSuccessEL)

    if testFailedEL?
        $(e).find(".todo-detail").append(testFailedEL)


genTestSuccessEL = (data, projectGuid, todoGuid)->

    # rest request
    el = $(document.createElement("a"))
    el.attr(
        href: "javascript:void(0)"
    )
    el.bind("click", {todoGuid:todoGuid}, testSuccessClickEvent)
    el.text("测试通过")
    el.addClass("label no-assign")
    el.addClass("dtask-hd-label")
    el.addClass("dtask-test-decision-label")
    el.css(
        "background-color":"#99FF66"
        "color": "black"
    )

    return el


testSuccessClickEvent = (e)->
    result = "passed"
    todoGuid = e.data.todoGuid
    $.ajax(
        url: "#{dtaskUrl}/hacking_day/mission/test_result"
        type: "PUT"
        dataType:"json"
        data:
            todo_guid: todoGuid
            member_guid: userGuid
            todo_title: title
            result: result
        success: (data)->
            testSuccessResult(data, todoGuid)
        error: (req, msg, e)->
            console.log("send test success result request error: ", msg)
            error = true
    )


testSuccessResult = (data, todoGuid)->

    reorderScript = getReorderTodoScript_2RegressList(todoGuid)

    addTowerComment(COMMENT_TEST_SUCCESS)

    hackDialogJs = """simple.dialog.confirm(
        {content:"#{COMMENT_TEST_SUCCESS_DIAG}",
        buttons:[{
            text: "知道啦~ ^o^",
            callback: function(e){
                        location.reload()
                    }
                }
            ]}
        )"""

    runOnPage(reorderScript + hackDialogJs)
    #runOnPage(reorderScript)


genTestFailedEL = (data, projectGuid, todoGuid)->

    # rest request
    el = $(document.createElement("a"))
    el.attr(
        href: "javascript:void(0)"
    )
    el.bind("click", {data:data, todoGuid:todoGuid}, testFailedClickEvent)
    el.text("测试失败")
    el.addClass("label no-assign")
    el.addClass("dtask-hd-label")
    el.addClass("dtask-test-decision-label")
    el.css(
        "background-color":"#f55"
        "color": "black"
    )

    return el


testFailedClickEvent = (e)->

    result = "failed"
    todoGuid = e.data.todoGuid
    $.ajax(
        url: "#{dtaskUrl}/hacking_day/mission/test_result"
        type: "PUT"
        dataType:"json"
        data:
            todo_guid: todoGuid
            member_guid: userGuid
            todo_title: title
            result: result
        success: (data)->
            testFailedResult(data, todoGuid)
        error: (req, msg, e)->
            console.log("send test success result request error: ", msg)
            error = true
    )


testFailedResult = (data, todoGuid)->

    reorderScript = getReorderTodoScript_2UncompletedList(todoGuid)

    addTowerComment(COMMENT_TEST_FAILED)

    hackDialogJs = """simple.dialog.confirm(
        {content:"#{COMMENT_TEST_FAILED_DIAG}",
        buttons:[{
            text: "知道了",
            callback: function(e){
                        location.reload()
                    }
                }
            ]}
        );"""

    runOnPage(reorderScript + hackDialogJs)


genTestRequestEL = (data, projectGuid, todoGuid)->

    # rest request
    testRequest = $(document.createElement("a"))
    testRequestHackJs = getTestRequestHackJs(data, projectGuid, todoGuid)
    testRequest.attr(
        href: "javascript:void(0)"
        #onclick: testRequestHackJs
    )
    testRequest.bind("click", {data:data, todoGuid:todoGuid}, testRequestClickEvent)
    testRequest.text("请求测试")
    testRequest.addClass("label no-assign")
    testRequest.addClass("dtask-hd-label")
    testRequest.addClass("dtask-test-request-label")
    testRequest.css(
        "background-color":"#99FF66"
        "color": "black"
    )

    return testRequest


renderTestRequestLabel = (data, projectGuid, todoGuid)->

    # add label
    e = $(".todo[data-guid=#{todoGuid}]")

    e.find(".dtask-test-request-label").remove()

    testRequestEL = genTestRequestEL(data, projectGuid, todoGuid)
    $(e).find(".todo-detail").append(testRequestEL)


# ----------- tools -------------- #
addTowerComment = (content)->
    $(".fake-textarea").click()
    $(".simditor-body").html("<p>#{content}</p>")
    $(".btn-create-comment").click()

showTowerMsgDiag = (content) ->
    hackDialogJs = """simple.dialog.message({content:"#{content}"})"""
    runOnPage(hackDialogJs)

getReorderTodoScript_2TestList = (todoGuid)->
    distGuid = hackingDayData.testRequest
    return getReorderTodoScript(todoGuid, distGuid)


getReorderTodoScript_2UncompletedList = (todoGuid)->
    distGuid = hackingDayData.uncompleted
    return getReorderTodoScript(todoGuid, distGuid)


getReorderTodoScript_2RegressList = (todoGuid)->
    distGuid = hackingDayData.regress
    return getReorderTodoScript(todoGuid, distGuid)


getReorderTodoScript = (todoGuid, distGuid, projectGuid)->
    if not projectGuid?
        projectGuid = hackingDayData.project
    script = """
    $.ajax({
        url:"https://tower.im/projects/#{projectGuid}/todos/#{todoGuid}/reorder",
        data: {"list_guid":"#{distGuid}", "completed":false}
    });
    """
    return script


runOnPage = (code)->
    #console.log(code)
    location.href = "javascript: #{code}; void 0;"


getUserData = ()->
    $.ajax(
        url: "#{dtaskUrl}/hacking_day/member"
        dataType:"json"
        data:
            member_guid: userGuid
        success: (data)->
            getUserDataResult(data)
        error: (req, msg, e)->
            console.log("get user role request error: ", msg)
            error = true
    )


getUserDataResult = (data)->
    userData = data.result?.member
    if not userData?
        userData = ""
        console.error("get hacking_day/member error, user_role is null")

    port.postMessage(
        type: "cache_store"
        cache:
            "hacking_day_user_data": userData
    )


getGroupInfo = () ->
    $.ajax(
        url: "#{dtaskUrl}/hacking_day/groups"
        dataType:"json"
        data:
            member_guid: userGuid
        success: (data)->
            getGrupInfoResult(data)
        error: (req, msg, e)->
            console.log("getting group info request error: ", msg)
            error = true
    )


getGrupInfoResult = (data) ->
    groupData = data.result
    if not groupData?
        groupData = ""
        console.error("get hacking_day/groups error, group info is null")

    port.postMessage(
        type: "cache_store"
        cache:
            "hacking_day_group_data": groupData
    )


# start
port.postMessage(
    type: "query_hacking_day_url"
)


port.postMessage(
    type: "cache_get"
    key: "hacking_day_user_data"
)


port.postMessage(
    type: "cache_get"
    key: "hacking_day_group_data"
)

dtaskUpdateIntvl = setInterval(dtaskUpdate, 1000)

