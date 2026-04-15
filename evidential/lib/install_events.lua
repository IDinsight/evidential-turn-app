local turn = require("turn")
local Functions = {}

function Functions.install()
    local manifest_json = turn.assets.load("manifest.json")
    local manifest = turn.json.decode(manifest_json)
    turn.logger.info("Installing from the manifest file")
    turn.manifest.install(manifest)

    -- Set default config values
    local success_config, _ = turn.app.update_config(manifest.config)

    -- Subscribe to contact field changes for experiment_id and assignment_arm_id
    local contact_subscriptions = turn.app.get_contact_subscriptions()
    table.insert(contact_subscriptions, "experiment_id")
    table.insert(contact_subscriptions, "assignment_arm_id")
    local success_subscriptions, _ = turn.app.set_contact_subscriptions(
                                         contact_subscriptions)

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
end

function Functions.uninstall()
    -- Clean up subscriptions and data dictionary
    turn.app.set_contact_subscriptions({})
    local experiment_data = turn.data.dictionary.get_global(
                                "evidential_experiment")
    if experiment_data and experiment_data.arms then
        local arms = experiment_data.arms
        if type(arms) == "string" then arms = turn.json.decode(arms) end
        for _, journey_uuid in pairs(arms) do
            local journey = turn.journeys.get(journey_uuid)
            if journey then turn.journeys.delete(journey_uuid) end
        end

        turn.data.dictionary.delete_global("evidential_experiment")
    end

    turn.logger.info("App uninstalled")
    return true
end

return Functions
