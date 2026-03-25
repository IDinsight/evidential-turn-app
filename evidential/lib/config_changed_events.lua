local turn = require("turn")
local Functions = {}

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

    journey_mapping = turn.app.get_journey_mapping()
    for arm_id, journey_uuid in pairs(experiment_config.arms) do
        arm_id = tostring(arm_id)
        if not table.contains(journey_mapping, journey_uuid) then
            turn.logger.error(
                "Invalid journey UUID for arm " .. arm_id .. ": " ..
                    tostring(journey_uuid))
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
