local lester = require('lester')
local turn = require('turn')
local json = turn.json -- JSON encoding/decoding from turn module
local JourneyEvents = require('lib/journey_events')

local describe, it, before = lester.describe, lester.it, lester.before

package.path = "../?.lua;../lib/?.lua;" .. package.path

describe("journey_events", function()
    local app_config
    local contact_id

    before (function()
        turn.test.reset()

        app_config = {
            evidential_api_key = "your-api-key",
            evidential_organization_id = "your-organization-id",
            evidential_api_base_url = "https://api.evidential.com/v1/experiments",
            experiment_id = "experiment_123"
        }
        contact_id = "contact_123"
    end)

    describe("get_assignment_for_contact", function()
        it("should make an http call to get assignment for contact",
           function()
            -- Mock the HTTP response
            turn.test.mock_http({
                url = string.format("%s/%s/assignments/%s",
                                    app_config.evidential_api_base_url,
                                    app_config.experiment_id, contact_id),
                method = "GET",
                headers = {
                    ["Authorization"] = "Bearer " .. app_config.evidential_api_key,
                    ["Accept"] = "application/json"
                }
            }, {
                status_code = 200,
                -- headers = {["content-type"] = "application/json"},
                body = turn.json.encode({
                    experiment_id = "experiment_123",
                    participant_id = "contact_123",
                    assignment = {
                        arm_id = "abcde",
                        participant_id = "contact_123",
                        arm_name = "Arm 1",
                        created_at = "2026-02-09T09:53:52.987Z",
                        observed_at = "2026-02-09T09:53:52.987Z"
                    }
                    })
            })
            
            local response, err =
                JourneyEvents.get_assignment_for_contact(contact_id, app_config)
            -- assert(err == nil, "Expected no error")
            -- assert(response.contact_id == contact_id,
            --        "Expected contact_id to match")
            -- assert(response.experiment_id == app_config.experiment_id,
            --        "Expected experiment_id to match")
            -- assert(response.group == "treatment",
            --        "Expected group to be treatment")
        end)
    end)
end)