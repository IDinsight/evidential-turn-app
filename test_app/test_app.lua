local App = {}
local turn = require("turn")

--[[
  Main entry point for all app events.

  Available events:
  - install: Called when app is installed for a number
  - uninstall: Called when app is uninstalled
  - config_changed: Called when app configuration changes
  - contact_changed: Called when subscribed contact fields change
  - journey_event: Called from Journey app() blocks
  - http_request: Called when webhook receives HTTP request
  - get_app_info_markdown: Return documentation to display in UI
]]
function App.on_event(app, number, event, data)
  turn.logger.info("Event received: " .. event)

  if event == "install" then
    -- Subscribe to contact field changes
    local success, reason = turn.app.set_contact_subscriptions({
      "name", "surname", "language"
    })

    if not success then
      turn.logger.error("Failed to set subscriptions: " .. reason)
      return false
    end

    turn.logger.info("App installed successfully!")
    return true

  elseif event == "uninstall" then
    -- Clean up subscriptions
    turn.app.set_contact_subscriptions({})
    turn.logger.info("App uninstalled")
    return true

  elseif event == "config_changed" then
    local config = turn.app.get_config()
    turn.logger.info("Config updated: " .. turn.json.encode(config))
    return true

  elseif event == "contact_changed" then
    local contact = data.contact or data
    turn.logger.info("Contact changed: " .. contact.uuid)
    return true

  elseif event == "journey_event" then
    local function_name = data.function_name
    local args = data.args

    if function_name == "hello" then
      return "continue", { message = "Hello from test_app!" }
    else
      return "error", "Unknown function: " .. function_name
    end

  elseif event == "http_request" then
    -- Handle webhook requests
    if data.method == "GET" and data.path_info[1] == "health" then
      return true, {
        status = 200,
        headers = { ["content-type"] = "application/json" },
        body = turn.json.encode({ status = "ok" })
      }
    end

    return true, {
      status = 404,
      headers = { ["content-type"] = "application/json" },
      body = turn.json.encode({ error = "Not found" })
    }

  elseif event == "get_app_info_markdown" then
    local readme = turn.assets.load("README.md")
    if readme then
      return readme
    end

    return "# test_app\\n\\nApp documentation goes here."

  else
    turn.logger.warning("Unknown event: " .. event)
    return false
  end
end

return App
