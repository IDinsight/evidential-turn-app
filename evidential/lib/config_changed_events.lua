local turn = require("turn")
local Functions = {}
local EVIDENTIAL_API_BASE_URL = "https://api.evidential.dev/v1"
local JOURNEYS_CHECK_INTERVAL_SECS = 300 -- 5 mins

--[[ Returns a redacted copy of the config so it can be used for logging. ]]
function Functions.redact_config_secrets(app_config)
    local logsafe = {}
    for k, v in pairs(app_config) do logsafe[k] = v end
    if logsafe.evidential_api_key then
        local key = tostring(logsafe.evidential_api_key)
        local shadow = string.sub(key, 1, 8) .. "****"
        logsafe.evidential_api_key = shadow
    end
    if logsafe.evidential_webhook_auth_token then
        local token = tostring(logsafe.evidential_webhook_auth_token)
        local shadow = string.sub(token, 1, 8) .. "****"
        logsafe.evidential_webhook_auth_token = shadow
    end
    return logsafe
end

local function get_current_journeys()
    local journeys = turn.journeys.list()
    local journeys_snapshot = {}
    for _, journey in ipairs(journeys) do
        table.insert(journeys_snapshot,
                     {uuid = journey.uuid, name = journey.name})
    end
    -- Sort the journeys snapshot by UUID to ensure consistent ordering for comparison
    table.sort(journeys_snapshot, function(a, b) return a.uuid < b.uuid end)
    return journeys_snapshot
end

function Functions.journeys_changed()
    local last_checked = turn.data.dictionary
                             .get_global("journeys_last_checked")
    local current_time = os.time()
    if last_checked and (current_time - last_checked.last_snapshot_time) <
        JOURNEYS_CHECK_INTERVAL_SECS then
        turn.logger.info("Journeys check skipped; last checked " ..
                             tostring(
                                 current_time - last_checked.last_snapshot_time) ..
                             " seconds ago")
        return false
    end

    local stored_snapshot =
        turn.data.dictionary.get_global("journeys_snapshot") or
            {["journeys"] = {}}
    local current_snapshot = get_current_journeys()
    local current_json = turn.json.encode(current_snapshot)
    if turn.json.encode(stored_snapshot["journeys"]) ~= current_json then
        turn.logger.info("Journey list changed; updating global snapshot")
        turn.data.dictionary.set_global("journeys_snapshot",
                                        {["journeys"] = current_snapshot},
                                        {replace = true})
        turn.logger.info("Updating last checked timestamp for journeys")
        turn.data.dictionary.set_global("journeys_last_checked",
                                        {last_snapshot_time = current_time})
        turn.logger.info("Journeys snapshot updated successfully")
        return true
    end
    turn.logger
        .info("No changes in journeys; global snapshot remains unchanged")
    return false
end

function Functions.notify_refresh_journeys(app_config)
    -- Notify Evidential webhook about the journey changes
    local url = string.format("%s/integrations/turn/webhook/%s/config-updated",
                              EVIDENTIAL_API_BASE_URL,
                              tostring(app_config.evidential_webhook_id))
    local body, status_code = turn.http.request({
        url = url,
        method = "POST",
        headers = {
            ["Webhook-Token"] = tostring(
                app_config.evidential_webhook_auth_token)
        }
    })

    if status_code >= 200 and status_code < 300 then
        turn.logger.info(
            "Evidential webhook notified successfully for refresh-journeys")
        return true
    else
        turn.logger.error(
            "Failed to notify Evidential webhook for refresh-journeys: HTTP " ..
                tostring(status_code) .. " - " .. tostring(body))
        return nil,
               "Failed to notify Evidential webhook for refresh-journeys: HTTP " ..
                   tostring(status_code)
    end
end

--[[ Validates the app's config and sets the experiment config in the data dictionary. ]]
function Functions.set_experiment_config(app_config, experiment_id)
    -- notify Evidential webhook to refresh journeys in case the 
    -- journey was recently created or updated

    local url = string.format("%s/integrations/experiments/%s/turn-app-config",
                              EVIDENTIAL_API_BASE_URL, experiment_id)
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

    turn.data.dictionary.set_global(string.format("evidential_experiment_%s",
                                                  experiment_config.experiment_id),
                                    {
        experiment_id = experiment_config.experiment_id,
        experiment_name = experiment_config.experiment_name,
        arm_journey_map = experiment_config.arm_journey_map
    }, {replace = true})
    turn.logger.info("Experiment config set successfully for experiment " ..
                         experiment_config.experiment_id)

    turn.data.dictionary.set_global("evidential_experiment_index", {
        [string.format("evidential_experiment_%s",
                       experiment_config.experiment_id)] = true
    }, {append = true})
    turn.logger.info("Experiment config added to index for experiment " ..
                         experiment_config.experiment_id)

    local logsafe = Functions.redact_config_secrets(app_config)
    turn.logger.info("Fetched experiment config with app config: " ..
                         turn.json.encode(logsafe))
    turn.logger.info("Config validated: experiment=" ..
                         experiment_config.experiment_id .. ", arm_journey_map=" ..
                         turn.json.encode(experiment_config.arm_journey_map))
    return true
end

function Functions.sync_config()
    local manifest_json = turn.assets.load("manifest.json")
    local manifest = turn.json.decode(manifest_json)

    local existing_config = turn.app.get_config()

    local merged = {}
    for key, value in pairs(existing_config or {}) do
        merged[key] = value -- keep values the admin already set
    end
    for key, value in pairs(manifest.config or {}) do
        if merged[key] == nil then merged[key] = value end -- fill only missing keys
    end

    -- Set default config values
    local success_config, _ = turn.app.update_config(merged)

    turn.logger.info("App config synced successfully")
    return true
end

return Functions
