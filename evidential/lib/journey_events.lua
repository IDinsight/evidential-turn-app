local turn = require("turn")
local Functions = {}

function Functions.get_assignment_for_contact(contact_id, experiment_id)
    local url = string.format("%s/%s/assignments/%s",
                              turn.app.get_config_value("evidential_api_base_url"),
                              experiment_id, 
                              contact_id)
    local response = turn.http.request({
        url = url,
        method = "GET",
        headers = {
            ["X-API-Key"] = tostring(turn.app.get_config_value("evidential_api_key")),
        }
    })

    if response.status_code == 200 then
        local response_body = turn.json.decode(response.body)
        return response_body.assignment.arm_id
    else
        turn.logger.error("Failed to get assignment: " .. response.body)
        return nil, "Failed to get assignment: " .. response.body
    end
end

function Functions.post_outcome_for_contact(contact_id, experiment_id, outcome)
    local url = string.format("%s/%s/assignments/%s/outcome",
                              turn.app.get_config_value("evidential_api_base_url"),
                              experiment_id, 
                              contact_id)
    local response = turn.http.request({
        url = url,
        method = "POST",
        headers = {
            ["X-API-Key"] = tostring(turn.app.get_config_value("evidential_api_key")),
            ["Content-Type"] = "application/json"
        },
        body = turn.json.encode({ outcome = outcome })
    })

    if response.status_code == 200 then
        local response_body = turn.json.decode(response.body)
        return response_body
    else
        turn.logger.error("Failed to post outcome: " .. response.body)
        return nil, "Failed to post outcome: " .. response.body
    end
end

return Functions
