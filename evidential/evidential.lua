local App = {}
local turn = require("turn")
local JourneyEvents = require("lib/journey_events")
local InstallEvents = require("lib/install_events")
local ConfigChangedEvents = require("lib/config_changed_events")

function App.check_journeys_changed()
    local are_journeys_changed = ConfigChangedEvents.journeys_changed()
    if are_journeys_changed then
        turn.logger.info("Journeys have changed since last snapshot")
        local config = turn.app.get_config()
        ConfigChangedEvents.notify_refresh_journeys(config)
    else
        turn.logger.info("No changes in journeys since last snapshot")
    end
end
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
  - upgrade: Called when app is upgraded to a new version
  - downgrade: Called when app is downgraded to a previous version
]]
function App.on_event(app, number, event, data)
    turn.logger.info("on_event: " .. event)

    -- if event ~= "install" and event ~= "uninstall" and event ~= "upgrade" and event ~= "downgrade" then
    --     -- For all events except install/uninstall, we need to ensure that the app config is valid
    --     local config = turn.app.get_config()
    --     if not config.evidential_api_key or not config.evidential_webhook_id or not config.evidential_webhook_auth_token then
    --         local msg = "Evidential app configuration is missing required fields. Please ensure that 'evidential_api_key', 'evidential_webhook_id', and 'evidential_webhook_auth_token' are set in the app configuration."
    --         turn.logger.error(msg)
    --         return "error", msg
    --     end
    -- end

    if event == "install" then
        return InstallEvents.install()

    elseif event == "uninstall" then
        return InstallEvents.uninstall()

    elseif event == "contact_changed" then
        local contact = data.contact or data
        turn.logger.info("Contact changed: " .. contact.uuid)
        return true

    elseif event == "config_changed" then
        local success, err = ConfigChangedEvents.sync_config()
        if not success then
            turn.logger.error("Failed to sync config: " .. tostring(err))
            return "error", "Failed to sync config: " .. tostring(err)
        end
        App.check_journeys_changed()
        return true

    elseif event == "journey_event" then

        App.check_journeys_changed()

        local config = turn.app.get_config()
        local function_name = data.function_name
        local args = data.args

        -- Always update the config, journeys snapshot, and experiment data from the data dictionary 
        -- at the start of a journey event in case they have changed since the last event
        local experiment_id = args[2]

        -- Look up experiment data from the global data dictionary
        local experiment_data = turn.data.dictionary.get_global(string.format(
                                                                    "evidential_experiment_%s",
                                                                    experiment_id))

        if not experiment_data then
            local success = ConfigChangedEvents.set_experiment_config(config,
                                                                      experiment_id)
            if not success then
                local logged_config = ConfigChangedEvents.redact_config_secrets(
                                          config)
                local msg =
                    "Invalid experiment config. Check that you have a valid API key and experiment ID."
                turn.logger
                    .error(msg .. ": " .. turn.json.encode(logged_config))
                return "error", msg
            else
                experiment_data = turn.data.dictionary.get_global(string.format(
                                                                      "evidential_experiment_%s",
                                                                      experiment_id))
            end
        else
            turn.logger.info(
                "Fetched experiment data from dictionary for experiment " ..
                    tostring(experiment_id) .. ": " ..
                    turn.json.encode(experiment_data))
        end

        if function_name == "route_to_experiment" then
            assert(#args >= 2, "Expected 2 arguments for route_to_experiment")
            local contact_id, experiment_id = args[1], args[2]
            return JourneyEvents.route_to_journey(contact_id, experiment_id,
                                                  experiment_data,
                                                  data.chat_uuid,
                                                  data.contact_uuid)

        elseif function_name == "get_assignment_for_contact" then
            assert(#args >= 2,
                   "Expected 2 arguments for get_assignment_for_contact")
            local contact_id, experiment_id, update_contact_fields = args[1],
                                                                     args[2],
                                                                     args[3]

            local contact_uuid = nil
            if update_contact_fields then
                contact_uuid = data.contact_uuid
            end

            local result, err = JourneyEvents.get_assignment_for_contact(
                                    contact_id, experiment_id, experiment_data,
                                    contact_uuid)
            if result then
                return "continue", {
                    assignment = result.arm_id,
                    experiment_id = result.experiment_id,
                    journey_uuid = result.journey_uuid
                }
            else
                turn.logger.error(err)
                return "error", err
            end

        elseif function_name == "post_outcome_for_contact" then
            assert(#args == 3,
                   "Expected 3 arguments for post_outcome_for_contact")
            local contact_id, experiment_id, outcome = args[1], args[2], args[3]
            local response, err = JourneyEvents.post_outcome_for_contact(
                                      contact_id, experiment_id, outcome,
                                      experiment_data, data.contact_uuid)
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

        return "# Evidential\\n\\nApp documentation goes here."

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
