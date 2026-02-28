local App = {}
local turn = require("turn")
local JourneyEvents = require("lib/journey_events")

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
        -- Load manifest and update app config with manifest config
        local manifest_json = turn.assets.load("manifest.json")
        local manifest = turn.json.decode(manifest_json)
        turn.logger.info("Installing from the manifest file")
        turn.manifest.install(manifest)

        local success_config, _ = turn.app.update_config(manifest.app.config) -- Store manifest in app config for later use

        -- Subscribe to contact field changes for experiment_id and assignment_arm_id
        local contact_subscriptions = turn.app.get_contact_subscriptions()
        table.insert(contact_subscriptions, "experiment_id")
        table.insert(contact_subscriptions, "assignment_arm_id")
        local success_subscriptions, _ =
            turn.app.set_contact_subscriptions(contact_subscriptions) -- Subscribe to contact field changes

        if not success_config then
            turn.logger.error("Failed to update config")
            return false
        end

        if not success_subscriptions then
            turn.logger.error("Failed to set contact subscriptions")
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

        if function_name == "get_assignment_for_contact" then
            local contact_id, experiment_id = args[1], args[2]

            local response, err = JourneyEvents.get_assignment_for_contact(
                                      contact_id, experiment_id)
            if response then
                return "continue", {assignment = response}
            else
                turn.logger.error(err)
                return "error", err
            end

        elseif function_name == "post_outcome_for_contact" then
            contact_id, experiment_id, outcome = args[1], args[2], args[3]
            local response, err = JourneyEvents.post_outcome_for_contact(
                                      contact_id, experiment_id, outcome)
            if response then
                return "continue", {outcome_response = response}
            else
                turn.logger.error(err)
                return "error", err
            end
        else
            turn.logger.warning("Unknown journey function: " .. function_name)
            return "error", "Unknown journey function: " .. function_name
        end

    elseif event == "get_app_info_markdown" then
        local readme = turn.assets.load("README.md")
        if readme then return readme end

        return "# test_app\\n\\nApp documentation goes here."
    elseif event == "upgrade" then
        return true
    elseif event == "downgrade" then
        return true
    else
        turn.logger.warning("Unknown event: " .. event)
        return false
    end
end

return App
