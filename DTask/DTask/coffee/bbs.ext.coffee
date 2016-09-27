url_params = $.parseParams(location.search.substr(1))
FB_BASE = "http://feedback.deepin.org"
SUBMIT_BTN_TEXT = "提交"
SUBMIT_DEFAULT_TEXT = "-- 提交到feedback --"
JUMP_BTN_TEXT = "跳到feedback"
USERNAME = $(".username").text()
_lz_src = $(".thread-info img").attr("src")
LZ_UID = parseInt(/.*uid=(\d+).*/.exec(_lz_src)[1])
POST_CONTENT = $(".main").find(".t_f").text()
TITLE = $("#thread_subject").text().trim()
LANG = $.cookie "deepin_language"

get_bbs_post_status = ()->
    # search the match feedback
    onsuccess = (data)->
        found = false
        fb_id = 0
        for item in data
            if item.uid == LZ_UID and item.title.trim() == TITLE
                found = true
                fb_id = item.id
                break

        if found
            fb_url = "#{FB_BASE}/feedback/detail/#{fb_id}"
            render_jump_button(fb_url)
        else
            render_submit_button()

    search_url = "#{FB_BASE}/feedback/bbshint?word=#{TITLE}"
    return $.get(search_url).then((data)->
        onsuccess(data)
    )


render_jump_button = (url)->
    btn = $(document.createElement("button"))
    btn.click(()->
        window.open(url)
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
    btn.click(submit_click_event)

    $(".thread-info > h1").append(btn)


collect_data = ()->
    # time
    ctime = format_time_str(new Date())

    # content
    desc_tag = "\n\n --- from: #{location.href}"
    text = POST_CONTENT + desc_tag

    # component
    component = $('#DTask_bugz_component_select option:selected').val()

    # files
    files = []
    for img in $(".main").find(".t_f").find("img")
        src = img.getAttribute("file")
        path = "#{location.origin}/#{src}"
        files.push(path)

    return {"uid": LZ_UID, "ctime": ctime, "title": TITLE, "content": text, "type": component, "files": files}


format_time_str = (d)->
    _transfer = (datetime_str)->
        string = "" + datetime_str
        if string.length == 1
            string = "0" + string
        return string
    month = _transfer(d.getMonth() + 1)
    date = _transfer(d.getDate())
    hours = _transfer(d.getHours())
    minutes = _transfer(d.getMinutes())
    return "#{d.getFullYear()}-#{month}-#{date} #{hours}:#{minutes}"


submit_bugz = (params)->
    console.log(params)
    url = "#{FB_BASE}/postfrombbs"
    return $.ajax(
            type: "post"
            url: url
            data: JSON.stringify(params)
            headers:
                "Content-Type": "application/json"
            success: (data)->
                console.log("finish submitting to feedback")
                console.log(data)
                if data.ret == 1
                    location.reload()
                else
                    $("#DTask_waiting").text("(DTask: 提交失败，#{data.message})")
    )


render_waitting_label = ()->
    $(".DTask_tag").remove()
    waiting = $(document.createElement("label"))
    waiting.attr(
        "id": "DTask_waiting"
    )
    waiting.text("bug提交中...")
    waiting.addClass("bugz_waiting DTask_tag")
    $(".thread-info > h1").append(waiting)


fill_options = (select)->
    # append the default option
    option = $(document.createElement("option"))
    default_name = SUBMIT_DEFAULT_TEXT
    option.text(default_name)
    option.attr(
        "value": "none"
    )
    select.append(option)

    # append the fb types
    fb_type_url = "#{FB_BASE}/feedback/bbstype"

    $.get(fb_type_url).then((data)->
        lang = if LANG == "zh-cn" then "zh_cn" else "en"
        for own key, value of data[lang]
            option = $(document.createElement("option"))
            option.text(value)
            option.attr(
                "value": value
            )
            select.append(option)
    )


submit_click_event = ()->
    params = collect_data()  # collect web data
    render_waitting_label()
    return submit_bugz(params)


$.get("https://tools.deepin.io/dtask/plugin/services/bbs2bugzilla/admin_users").then((data)->
    data = $.parseJSON(data)
    if data["users"].indexOf(USERNAME) != -1
        get_bbs_post_status()
)

console.log("bbs extension loaded")
