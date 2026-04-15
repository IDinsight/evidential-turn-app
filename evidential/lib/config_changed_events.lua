local turn = require("turn")
local Functions = {}

--[[ Returns a redacted copy of the config so it can be used for logging. ]]
function Functions.redact_config_secrets(app_config)
    local logsafe = {}
    for k, v in pairs(app_config) do logsafe[k] = v end
    if logsafe.evidential_api_key then
        local key = tostring(logsafe.evidential_api_key)
        local shadow = string.sub(key, 1, 8) .. "****"
        logsafe.evidential_api_key = shadow
    end
    return logsafe
end

--[[ Validates the app's config and sets the experiment config in the data dictionary. ]]
function Functions.set_experiment_config(app_config)
    local experiment_config_raw = app_config.experiment_config

    -- Validate raw config
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

    -- Validate required fields in parsed config
    if not experiment_config.experiment_id then
        turn.logger.error(
            "Experiment config missing required field: experiment_id")
        return false
    end

    if not experiment_config.arms then
        turn.logger.error("Experiment config missing required field: arms")
        return false
    end

    local arm_count = 0
    for _ in pairs(experiment_config.arms) do arm_count = arm_count + 1 end
    if arm_count < 2 then
        turn.logger.error("Experiment config arms must have at least two arms")
        return false
    end

    for arm_id, journey_uuid in pairs(experiment_config.arms) do
        arm_id = tostring(arm_id)
        journey = turn.journeys.get(journey_uuid)
        if not journey then
            turn.logger.error(
                "Invalid journey UUID for arm " .. arm_id .. ": " ..
                    tostring(journey_uuid) ..
                    " (Make sure the journey exists and is active)")
            return false
        end
    end

    -- Write parsed config to data dictionary so journey events
    -- can read structured data without re-parsing JSON on every call.
    -- Write to both local (for @local.evidential_experiment.* in Stacks)
    -- and global (for programmatic access from any journey context).

    -- local journey_mapping = turn.app.get_journey_mapping()
    -- for _, journey_uuid in pairs(journey_mapping) do
    --     turn.data.dictionary.set_local(journey_uuid, "evidential_experiment", {
    --         experiment_id = experiment_config.experiment_id,
    --         arms = experiment_config.arms
    --     }, { replace = true })
    -- end

    turn.data.dictionary.set_global("evidential_experiment", {
        experiment_id = experiment_config.experiment_id,
        arms = experiment_config.arms
    }, {replace = true})

    turn.logger.info("Config validated: experiment=" ..
                         experiment_config.experiment_id .. ", arms=" ..
                         turn.json.encode(experiment_config.arms))
    return true
end

return Functions
