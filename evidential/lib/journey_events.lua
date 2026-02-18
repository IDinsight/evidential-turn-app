local Functions = {}

function Functions.get_assignment_for_contact(contact_id, app_config)
    local url = string.format("%s/%s/assignments/%s",
                              app_config.evidential_api_base_url,
                              app_config.experiment_id, contact_id)
                            
    local body, status_code, headers = turn.http.request({
        url = url,
        method = "GET",
        headers = {
            ["Authorization"] = "Bearer " .. app_config.evidential_api_key,
            ["Accept"] = "application/json"
        }
    })

    if status_code == 200 then
        local response = turn.json.decode(body)
        return response
    else
        turn.logger.error("Failed to get assignment: " .. body)
        return nil, "Failed to get assignment: " .. body
    end
end

return Functions
