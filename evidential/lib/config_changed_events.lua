local turn = require("turn")
local Functions = {}
local EVIDENTIAL_API_BASE_URL = "https://api.evidential.dev/v1"

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
    local url = string.format("%s/integrations/experiments/%s/turn-app-config",
                              EVIDENTIAL_API_BASE_URL, app_config.experiment_id)
    local body, status_code = turn.http.request({
        url = url,
        method = "GET",
        headers = {["X-API-Key"] = tostring(app_config.evidential_api_key)}
    })

    -- Validate response and parse experiment config
    local experiment_config

    if status_code == 200 then
        turn.logger.info("Received 200 response from Evidential API")
        experiment_config = turn.json.decode(body)
        if not experiment_config then
            turn.logger.error(
                "Empty response body when fetching experiment config")
            return nil, "Invalid experiment config: empty response body"
        end
    else
        turn.logger.error("Failed to fetch experiment config: HTTP " ..
                              tostring(status_code) .. " - " .. tostring(body))
        return nil, "Failed to fetch experiment config: HTTP " ..
                   tostring(status_code)
    end

    if not experiment_config.experiment_id or
        not experiment_config.arm_journey_map then
        turn.logger.error(
            "Invalid experiment config: missing required fields. Received config: " ..
                turn.json.encode(experiment_config))
        return nil, "Invalid experiment config: missing required fields"
    end

    -- Validate Journey UUIDs in parsed config
    for arm_id, journey_uuid in pairs(experiment_config.arm_journey_map) do
        arm_id = tostring(arm_id)
        local journey = turn.journeys.get(journey_uuid)
        if not journey then
            turn.logger.error(
                "Invalid journey UUID for arm " .. arm_id .. ": " ..
                    tostring(journey_uuid) ..
                    " (Make sure the journey exists and is active)")
            return nil, "Invalid journey UUID for arm " .. arm_id
        end
    end

    turn.data.dictionary.set_global("evidential_experiment", {
        experiment_id = experiment_config.experiment_id,
        experiment_name = experiment_config.experiment_name,
        arm_journey_map = experiment_config.arm_journey_map
    }, {replace = true})

    turn.logger.info("Config validated: experiment=" ..
                         experiment_config.experiment_id .. ", arm_journey_map=" ..
                         turn.json.encode(experiment_config.arm_journey_map))
    return true
end

return Functions
