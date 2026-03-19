local turn = require("turn")
local Functions = {}

function Functions.get_assignment_for_contact(contact_id, experiment_data)
    local config = turn.app.get_config()

    local experiment_id = experiment_data.experiment_id

    local url = string.format("%s/%s/assignments/%s",
                              config.evidential_api_base_url,
                              experiment_id,
                              contact_id)

    local body, status_code = turn.http.request({
        url = url,
        method = "GET",
        headers = {
            ["X-API-Key"] = tostring(config.evidential_api_key),
        }
    })

    if status_code == 200 then
        local response_body = turn.json.decode(body)
        if not response_body or not response_body.assignment then
            return nil, "Invalid response: missing assignment data"
        end
        local arm_id = response_body.assignment.arm_id
        local journey_uuid = experiment_data.arms[arm_id]
        return {
            arm_id = arm_id,
            experiment_id = experiment_id,
            journey_uuid = journey_uuid
        }
    else
        return nil, "Failed to get assignment: " .. (body or "unknown error")
    end
end

function Functions.post_outcome_for_contact(contact_id, outcome, experiment_data)
    local config = turn.app.get_config()

    local experiment_id = experiment_data.experiment_id

    local url = string.format("%s/%s/assignments/%s/outcome",
                              config.evidential_api_base_url,
                              experiment_id,
                              contact_id)
    local body, status_code = turn.http.request({
        url = url,
        method = "POST",
        headers = {
            ["X-API-Key"] = tostring(config.evidential_api_key),
            ["Content-Type"] = "application/json"
        },
        body = turn.json.encode({outcome = outcome})
    })

    if status_code == 200 then
        local response_body = turn.json.decode(body)
        return response_body
    else
        return nil, "Failed to post outcome: " .. (body or "unknown error")
    end
end

return Functions
