local turn = require("turn")
local Functions = {}

function Functions.install()
    local manifest_json = turn.assets.load("manifest.json")
    local manifest = turn.json.decode(manifest_json)
    turn.logger.info("Installing from the manifest file")
    turn.manifest.install(manifest)

    -- Set default config values
    local success_config, _ = turn.app.update_config({
        evidential_api_base_url = "https://api.evidential.dev/v1/experiments"
    })

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
    turn.data.dictionary.delete_global("evidential_experiment")
    local journey_mapping = turn.app.get_journey_mapping()
    -- for _, journey_uuid in pairs(journey_mapping) do
    --     turn.data.dictionary.delete_local(journey_uuid, "evidential_experiment")
    -- end
    turn.logger.info("App uninstalled")
    return true
end

return Functions
