local turn = require("turn")
local Functions = {}
local EVIDENTIAL_API_BASE_URL = "https://api.evidential.dev/v1/experiments"

function Functions.route_to_journey(contact_id, experiment_data, chat_uuid, contact_uuid)
    local result, err = Functions.get_assignment_for_contact(
        contact_id, experiment_data, contact_uuid)
    if not result then
        turn.logger.error(err)
        return "error", err
    end

    if not result.journey_uuid then
        local msg = "No journey configured for arm: " .. tostring(result.arm_id)
        turn.logger.error(msg)
        return "error", msg
    end

    local success, start_result = turn.journeys.start(
        chat_uuid, result.journey_uuid, {override = true})

    if success then
        turn.logger.info("Routed contact " .. contact_id ..
            " to arm " .. result.arm_id ..
            " (journey " .. result.journey_uuid .. ")")
        return "continue", {routed = true, arm_id = result.arm_id}
    else
        turn.logger.error("Failed to start arm journey: " ..
            tostring(start_result))
        return "error", "Failed to start arm journey"
    end
end

function Functions.get_assignment_for_contact(contact_id, experiment_data, contact_uuid)
    local config = turn.app.get_config()

    local experiment_id = experiment_data.experiment_id

    local url = string.format("%s/%s/assignments/%s",
                              EVIDENTIAL_API_BASE_URL,
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
        
        -- Check that the arm_id from the API response is one of the arms defined in the 
        -- experiment config
        local arm_journey_map = experiment_data.arm_journey_map
        if type(arm_journey_map) == "string" then
            arm_journey_map = turn.json.decode(arm_journey_map)
        end
        local config_arm_ids = {}
        for arm_key, journey_uuid in pairs(arm_journey_map) do
            config_arm_ids[arm_key] = true
        end
        if not config_arm_ids[arm_id] then
            return nil, "Received unknown arm_id from API: " .. tostring(arm_id)
        end

        local journey_uuid = arm_journey_map[arm_id]
        
        local result =  {
            arm_id = arm_id,
            experiment_id = experiment_id,
            journey_uuid = journey_uuid
        }

        -- Update contact fields with experiment assignment info for use in Stacks and other journey contexts
        if contact_uuid ~= nil then
            local contact, found = turn.contacts.get(contact_uuid)
            if found then
                turn.contacts.update_contact_details(contact, {
                    assignment_arm_id = result.arm_id,
                    experiment_id = result.experiment_id,
                    assignment_outcome_recorded = false
                })
            else
                print("Log skip")
                turn.logger.warning("Contact not found for uuid: " .. tostring(contact_uuid) ..
                    ", skipping profile update")
            end
        end
        return result
    else
        return nil, "Failed to get assignment: " .. (body or "unknown error")
    end
end

function Functions.post_outcome_for_contact(contact_id, outcome, experiment_data, contact_uuid)
    local config = turn.app.get_config()

    local experiment_id = experiment_data.experiment_id

    local url = string.format("%s/%s/assignments/%s/outcome",
                              EVIDENTIAL_API_BASE_URL,
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

        
        -- Update contact field to indicate that the outcome has been recorded
        if contact_uuid ~= nil then
            local contact, found = turn.contacts.get(contact_uuid)
            if found then
                turn.contacts.update_contact_details(contact, {
                    assignment_outcome_recorded = true
                })
                turn.logger.info("Recorded outcome for contact " .. contact_id ..
                    ": outcome=" .. tostring(outcome))
            else
                turn.logger.warning("Contact not found for uuid: " .. tostring(contact_uuid) ..
                    ", skipping profile update")
            end
        end

        return response_body
    else
        return nil, "Failed to post outcome: " .. (body or "unknown error")
    end
end

return Functions
