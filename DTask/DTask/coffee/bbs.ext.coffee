BUGZ_RPC_URL = "https://bugzilla.deepin.io/jsonrpc.cgi"
SUBMIT_BTN_TEXT = "提交"
SUBMIT_DEFAULT_TEXT = "-- 提交到bugzilla --"
JUMP_BTN_TEXT = "跳到bugzilla"
BUGZ_DEFAULT_PRODUCT_NAME = "用户反馈"

url_params = $.parseParams(location.search.substr(1))


get_bbs_post_status = ()->

    # search the match bugz bbs url
    method = "Bug.search"
    tid = url_params["tid"]
    url = location.origin + location.pathname + "?mod=viewthread&tid=" + tid
    params = {"url": url}
    onsuccess = (data)->
        if data.result.bugs.length
            bugz_id = data.result.bugs[0].id
            bugz_url = "https://bugzilla.deepin.io/show_bug.cgi?id=#{bugz_id}"

            # found bbs bugz
            render_jump_button(bugz_url)
        else
            # bbs bugz not found
            render_submit_button()

    call_jsonrpc(method, params, onsuccess)


render_jump_button = (bugz_url)->
    btn = $(document.createElement("button"))
    btn.click(()->
        window.open(bugz_url)
    )
    btn.addClass("bugz_jump DTask_tag")
    btn.text(JUMP_BTN_TEXT)
    $(".thread-info > h1").append(btn)


render_submit_button = ()->
    select = $(document.createElement("select"))
    select.attr(
        "id": "DTask_bugz_component_select"
    )
    select.addClass("DTask_tag")
    fill_options(select)
    $(".thread-info > h1").append(select)

    btn = $(document.createElement("button"))
    btn.attr(
        "id": "DTask_bugz_submit_btn"
    )
    btn.text("提交")
    btn.addClass("bugz_submit DTask_tag")
    btn.click(bugz_submit_click_event)

    $(".thread-info > h1").append(btn)


collect_data = ()->

    # get email from another page
    cclist = ["tangcaijun@linuxdeepin.com"] # default cc
    profile_source = ""
    $.ajax(
        url: """#{location.origin}/#{$(".thread_tp .author > .xi2").attr("href")}"""
        async: false
        success: (data)->
            profile_source = data
        error: (data)->
            console.error("DTask err: failed to get email when getting profile source")
            console.log(data)
    )

    re = /<li><em>Email<\/em>([a-zA-Z0-9_-]+@[a-zA-Z0-9_-]+.[a-zA-Z0-9_-]+)<\/li>/
    re_list = re.exec(profile_source)
    if re_list?.length > 1
        email = re_list[1]
        cclist = [email]

    # get bugz title
    title = $("#thread_subject").text()

    # get bbs url
    tid = url_params["tid"]
    desc_tag = "\n\n --- from #{location.href} --- "
    text = $(".main").find(".t_f").text() + desc_tag
    url = location.origin + location.pathname + "?mod=viewthread&tid=" + tid

    product = BUGZ_DEFAULT_PRODUCT_NAME
    component = $('#DTask_bugz_component_select option:selected').val()

    console.log("DTask debug: bug submit: ", product, component, "cclist:", cclist)

    # debug
    #cclist = ["tangcaijun@linuxdeepin.com"]
    #product = "TestProduct"
    #component = "TestComponent"

    params = {"product": product, "component": component, "summary": title, "description": text, "cc": cclist, "url": url}
    return params


submit_bugz = (bugz_info)->

    # fuck the Bug.create API
    # url must be added by updating bug
    bbs_url = bugz_info["url"]
    delete bugz_info["url"]

    onsuccess = (data)->
        console.log("== submit bug ==")
        console.log(data)
        if data.result
            bugz_id = data.result.id

            # add url
            update_bugz_info = {"ids":[bugz_id], "url": bbs_url}
            update_bugz(update_bugz_info)
        else
            console.error("DTask err: failed to create bugz")

    # add bugz
    bugz_info["version"] = "1.0"
    return call_jsonrpc("Bug.create", bugz_info, onsuccess)


update_bugz = (bugz_info)->
    onsuccess = ()->
        $(".DTask_tag").remove()
        get_bbs_post_status()

    call_jsonrpc("Bug.update", bugz_info, onsuccess)

render_waitting_label = ()->
    $(".DTask_tag").remove()
    waiting = $(document.createElement("label"))
    waiting.attr(
        "id": "DTask_waiting"
    )
    waiting.text("bug提交中...")
    waiting.addClass("bugz_waiting DTask_tag")
    $(".thread-info > h1").append(waiting)


call_jsonrpc = (method, params, func_success, func_error, async)->
    if !func_success
        func_success = (data) ->
            console.log("call jsonrpc response success")
            console.log(data)

    if !func_error
        func_error = (data) ->
            console.log("call jsonrpc response error")
            console.log(data)

    if async == undefined
        async = true

    data_str = """{"method":"#{method}","params":#{JSON.stringify(params)},"version":"2.0"}"""
    #console.log("call_jsonrpc:")
    #console.log(data_str)

    return $.ajax(BUGZ_RPC_URL, {
        type: "POST",
        async: async,
        contentType: "application/json-rpc",
        data: data_str,
        success : func_success
        error : func_error
    })


fill_options = (select)->
    params = {"names": [BUGZ_DEFAULT_PRODUCT_NAME]}

    option = $(document.createElement("option"))
    default_name = SUBMIT_DEFAULT_TEXT
    option.text(default_name)
    option.attr(
        "value": "none"
    )
    select.append(option)

    onsuccess = (data)->
        if data.result and data.result.products.length > 0
            for item in data.result.products[0].components
                name = item["name"]
                option = $(document.createElement("option"))
                option.text(name)
                option.attr(
                    "value": name
                )
                select.append(option)
        else
            console.error("DTask err: failed to get product component")
            console.log(data)

    call_jsonrpc("Product.get", params, onsuccess)

    return select


bugz_submit_click_event = ()->

    # collect web data
    bugz_info = collect_data()

    render_waitting_label()

    cc_list = bugz_info["cc"]

    return check_user_exist(cc_list[0]).then(()->
        return submit_bugz(bugz_info)
    )


check_user_exist = (user)->

    return call_jsonrpc("User.get", {"names": user}).then((data)->
        console.log("== check user ==")
        console.log(data)
        if data.result?.users.length > 0
            return data
        else
            return create_user(user)
    )


create_user = (user)->
    onsuccess = (data)->
        console.log("== create user ==")
        console.log(data)
        return data

    return call_jsonrpc("User.create", {"email": user}, onsuccess)


username = $(".username").text()
$.get("https://tools.deepin.io/dtask/plugin/services/bbs2bugzilla/admin_users").then((data)->
    data = $.parseJSON(data)
    if data["users"].indexOf(username) != -1
        get_bbs_post_status()
)

console.log("bbs extension loaded")
