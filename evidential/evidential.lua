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
        turn.logger.info("Config updated")

        local experiment_config_raw = config.experiment_config
        if not experiment_config_raw then
            turn.logger.error("Experiment config is missing in app config")
            return false
        end

        local ok, experiment_config = pcall(turn.json.decode, experiment_config_raw)
        if not ok then
            turn.logger.error("Invalid JSON in experiment_config: " ..
                tostring(experiment_config))
            return false
        end

        if not experiment_config.experiment_id then
            turn.logger.error("Experiment config missing required field: experiment_id")
            return false
        end

        if not experiment_config.arms then
            turn.logger.error("Experiment config missing required field: arms")
            return false
        end

        local arm_count = 0
        for _ in pairs(experiment_config.arms) do arm_count = arm_count + 1 end
        if arm_count == 0 then
            turn.logger.error("Experiment config arms must not be empty")
            return false
        end

        turn.logger.info("Config validated: experiment=" ..
            experiment_config.experiment_id ..
            ", arms=" .. turn.json.encode(experiment_config.arms))
        return true

    elseif event == "contact_changed" then
        local contact = data.contact or data
        turn.logger.info("Contact changed: " .. contact.uuid)
        return true

    elseif event == "journey_event" then
        local function_name = data.function_name
        local args = data.args

        if function_name == "route_to_experiment" then
            assert(#args == 1, "Expected 1 argument for route_to_experiment")
            local contact_id = args[1]

            local result, err = JourneyEvents.get_assignment_for_contact(contact_id)
            if not result then
                turn.logger.error(err)
                return "error", err
            end

            if not result.journey_uuid then
                local msg = "No journey configured for arm: " .. tostring(result.arm_id)
                turn.logger.error(msg)
                return "error", msg
            end

            local contact, found = turn.contacts.find({msisdn = contact_id})
            if found then
                turn.contacts.update_contact_details(contact, {
                    assignment_arm_id = result.arm_id,
                    experiment_id = result.experiment_id
                })
            else
                turn.logger.warning("Contact not found for msisdn: " .. contact_id ..
                    ", skipping profile update")
            end

            local success, start_result = turn.journeys.start(
                data.chat_uuid, result.journey_uuid, {override = true})

            if success then
                turn.logger.info("Routed contact " .. contact_id ..
                    " to arm " .. result.arm_id ..
                    " (journey " .. result.journey_uuid .. ")")
                return "continue", {routed = true, arm_id = result.arm_id}
            else
                turn.logger.error("Failed to start arm journey: " ..
                    tostring(start_result))
                return "error", "Failed to start arm journey"
            end

        elseif function_name == "get_assignment_for_contact" then
            assert(#args == 1,
                   "Expected 1 argument for get_assignment_for_contact")
            local contact_id = args[1]

            local result, err = JourneyEvents.get_assignment_for_contact(
                                    contact_id)
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
            assert(#args == 2,
                   "Expected 2 arguments for post_outcome_for_contact")
            local contact_id, outcome = args[1], args[2]
            local response, err = JourneyEvents.post_outcome_for_contact(
                                      contact_id, outcome)
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
