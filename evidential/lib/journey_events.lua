local turn = require("turn")
local Functions = {}

function Functions.get_assignment_for_contact(contact_id, experiment_id)
    local url = string.format("%s/%s/assignments/%s",
                              turn.app.get_config_value("evidential_api_base_url"),
                              experiment_id, 
                              contact_id)
    local body, status_code, headers = turn.http.request({
        url = url,
        method = "GET",
        headers = {
            ["X-API-Key"] = tostring(turn.app.get_config_value("evidential_api_key")),
        }
    })

    if status_code == 200 then
        local response = turn.json.decode(body)
        return response.assignment.arm_id
    else
        turn.logger.error("Failed to get assignment: " .. body)
        return nil, "Failed to get assignment: " .. body
    end
end

return Functions
