port = chrome.runtime.connect({name:"dataconnect"})

port.onMessage.addListener((msg) ->
    switch msg.type
        when "bugz_store_tower_token_result"
            console.log("nothing need to be done, tmp")
)

$tokenMeta = $("meta[name=Tower-Token]")

if $tokenMeta
    d = setInterval(
        ()->
            con = $tokenMeta.attr("content")
            if con
                items = con.split(";")
                token = items[0]
                expires = 2592000
                csrf = items[2]
                port.postMessage(
                    type:"bugz_store_tower_token"
                    token:token
                    expires:expires
                    csrf:csrf
                )
                window.clearInterval(d)
        500
    )

