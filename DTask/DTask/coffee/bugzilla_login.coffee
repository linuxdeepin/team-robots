$("#loginForm").modal()
$("#loginForm").submit () ->
  $.ajax
    type: 'POST'
    url: "https://bugzilla.deepin.io/jsonrpc.cgi"
    contentType: "application/json-rpc; charset=utf-8"
    dataType: 'json'
    data: JSON.stringify(
      method: "User.login"
      version: "1.1"
      params: [
        login: $("#username").val()
        password: $("#password").val()
      ]
    )
    success: (data) ->
      if data.result?.token?
        chrome.cookies.set
          name: "bugzilla_token"
          url: "https://tower.im"
          value: data.result.token
          expirationDate: new Date().getTime()/1000 + 2592000
        chrome.tabs.getCurrent (tab) ->
          chrome.tabs.remove tab.id
      else
        $("#error").html("<span>Login failed</span>")
    error: () ->
      $("#error").html("<span>Login failed</span>")
  false
