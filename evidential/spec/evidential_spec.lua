local lester = require('lester')
local turn = require('turn')
local json = turn.json -- JSON encoding/decoding from turn module
local App = require('evidential')

local describe, it, before = lester.describe, lester.it, lester.before

describe("evidential", function()
    local app_config
    local number

    before(function()
        -- Reset the turn environment before each test suite
        turn.test.reset()

        -- Set up a default app config and experiment data in the data dictionary for testing
        app_config = {
            enabled = true,
            uuid = "evidential-app-uuid",
            config = {
                evidential_api_key = "your-api-key",
                evidential_organization_id = "your-organization-id",
                evidential_api_base_url = "https://api.evidential.com/v1/experiments",
                experiment_config = json.encode({
                    experiment_id = 'experiment_123',
                    arms = {arm_a = 'journey-1', arm_b = 'journey-2'}
                })
            }
        }

        turn.app.update_config(app_config.config)

        number = {id = "123", msisdn = "+1234567890"}

        -- Define a mock turn.data.dictionary for testing since the real one is not available 
        -- in this test environment
        turn.data = {
            dictionary = {
                global = {},
                set_global = function(key, value, opts)
                    turn.data.dictionary.global[key] = value
                end,
                get_global = function(key)
                    return turn.data.dictionary.global[key]
                end,
                delete_global = function(key)
                    turn.data.dictionary.global[key] = nil
                end
            }
        }

        turn.data.dictionary.set_global("evidential_experiment", {
            experiment_id = "experiment_123",
            arms = {arm_a = "journey-1", arm_b = "journey-2"}
        }, {replace = true})

        -- Set up test contact
        turn.test.add_contact({
            uuid = "test-route-contact",
            details = {msisdn = number.msisdn, name = "Test Contact"}
        })

        -- Set up test journeys for arms
        for i = 1, 3 do
            turn.test.add_journey({
                uuid = "journey-" .. i,
                name = "Journey " .. i,
                enabled = true
            })
        end

    end)

    describe("install event", function()
        it("should handle installation", function()
            local result = App.on_event(app_config, number, "install", {})
            assert(result == true, "Expected install to return true")
            -- assert(result.contact_fields.created == 2, "Expected 2 contact fields to be created")

            -- Verify app config was updated with manifest

            local config = turn.app.get_config()
            local required_fields = {
                "evidential_api_key", "evidential_organization_id",
                "evidential_api_base_url"
            }
            for _, field in ipairs(required_fields) do
                assert(config[field] ~= nil,
                       "Expected config to include " .. field)
            end
        end)
    end)

    describe("uninstall event", function()
        it("should handle uninstallation", function()
            local journeys_before = turn.journeys.list()
            local result = App.on_event(app_config, number, "uninstall", {})
            assert(result == true, "Expected uninstall to return true")

            experiment_data = turn.data.dictionary.get_global(
                                  "evidential_experiment")
            assert(experiment_data == nil,
                   "Expected experiment data to be deleted from data dictionary")

        end)
    end)

    describe("config_changed event", function()
        it("should handle config changes and update data dictionary", function()
            local new_config = {
                uuid = app_config.uuid,
                config = {
                    evidential_api_key = "new-api-key",
                    evidential_organization_id = "new-organization-id",
                    evidential_api_base_url = "new-base-url",
                    experiment_config = json.encode({
                        experiment_id = 'experiment_456',
                        arms = {arm_1 = 'journey-1', arm_2 = 'journey-2'}
                    })
                }
            }

            turn.app.update_config(new_config.config) -- Ensure config is updated before triggering event
            local result =
                App.on_event(new_config, number, "config_changed", {})
            assert(result == true, "Expected config_changed to return true")

            local config = turn.app.get_config()
            assert(config.evidential_api_key == "new-api-key",
                   "Expected API key to be updated in config")
            assert(config.evidential_organization_id == "new-organization-id",
                   "Expected organization ID to be updated in config")
            assert(config.evidential_api_base_url == "new-base-url",
                   "Expected API base URL to be updated in config")

            local experiment_data = turn.data.dictionary.get_global(
                                        "evidential_experiment")
            assert(experiment_data ~= nil,
                   "Expected experiment data to be set in data dictionary")
            assert(experiment_data.experiment_id == "experiment_456",
                   "Expected experiment_id to match config")
            assert(experiment_data.arms.arm_1 == "journey-1",
                   "Expected arm_1 to match config")
            assert(experiment_data.arms.arm_2 == "journey-2",
                   "Expected arm_2 to match config")

            -- assert that the logged config object shows only the redacted API key
            local info = turn.test.get_log_messages("info")
            assert(#info > 0, "Expected at least one info log entry: " ..
                       turn.json.encode(info))
            local found = false
            for _, entry in ipairs(info) do
                if entry.message:match("evidential_api_key.*new%-api%-%*%*%*%*") then
                    found = true
                    break
                end
            end
            assert(found,
                   "Expected **** in info log for evidential_api_key: " ..
                       turn.json.encode(info))

        end)

        it("should handle newlines in experiment_config", function()
            local new_config = {
                uuid = app_config.uuid,
                config = {
                    evidential_api_key = "new-api-key",
                    evidential_organization_id = "new-organization-id",
                    evidential_api_base_url = "new-base-url",
                    experiment_config = "\n{\"experiment_name\": \"name\\n2nd line\", " ..
                        "\n\"experiment_id\": \"exp_id1\"," ..
                        " \n \"arms\": {\"arm_1\": \"journey-1\", " ..
                        "\n\n \"arm_2\": \"journey-2\"}} \n "
                }
            }

            turn.app.update_config(new_config.config)
            local result =
                App.on_event(new_config, number, "config_changed", {})
            assert(result == true, "Expected config_changed to return true")

            local config = turn.app.get_config()
            assert(config.evidential_api_key == "new-api-key",
                   "Expected API key to be updated in config")
        end)

        it(
            "should NOT handle literal newlines in experiment_config string value",
            function()
                local new_config = {
                    uuid = app_config.uuid,
                    config = {
                        evidential_api_key = "new-api-key",
                        evidential_organization_id = "new-organization-id",
                        evidential_api_base_url = "new-base-url",
                        experiment_config = "{\"experiment_name\": \"name\n2nd line\", " ..
                            "\"experiment_id\": \"exp_id1\"," ..
                            " \"arms\": {\"arm_1\": \"journey-1\", " ..
                            "\"arm_2\": \"journey-2\"}}"
                    }
                }

                turn.app.update_config(new_config.config)
                local result = App.on_event(new_config, number,
                                            "config_changed", {})
                assert(result == false, "Expected config_changed to fail")
            end)

        it("should return false when experiment_config is missing", function()
            turn.app.set_config({
                evidential_api_key = "test-api-key",
                evidential_organization_id = "test-org-id",
                evidential_api_base_url = "https://api.evidential.com/v1/experiments"
            })
            local result =
                App.on_event(app_config, number, "config_changed", {})
            assert(result == false,
                   "Expected config_changed to return false when experiment_config is missing")
        end)

        it("should return false for malformed JSON in experiment_config",
           function()
            turn.app.set_config({
                evidential_api_key = "test-api-key",
                evidential_organization_id = "test-org-id",
                evidential_api_base_url = "https://api.evidential.com/v1/experiments",
                experiment_config = "not valid json{{"
            })
            local result =
                App.on_event(app_config, number, "config_changed", {})
            assert(result == false,
                   "Expected config_changed to return false for malformed JSON")
        end)

        it("should return false when experiment_id is missing", function()
            turn.app.set_config({
                evidential_api_key = "test-api-key",
                evidential_organization_id = "test-org-id",
                evidential_api_base_url = "https://api.evidential.com/v1/experiments",
                experiment_config = json.encode({arms = {arm_abc = "journey-1"}})
            })
            local result =
                App.on_event(app_config, number, "config_changed", {})
            assert(result == false,
                   "Expected config_changed to return false when experiment_id is missing")
        end)

        it("should return false when arms is missing", function()
            turn.app.set_config({
                evidential_api_key = "test-api-key",
                evidential_organization_id = "test-org-id",
                evidential_api_base_url = "https://api.evidential.com/v1/experiments",
                experiment_config = json.encode({
                    experiment_id = "experiment_123"
                })
            })
            local result =
                App.on_event(app_config, number, "config_changed", {})
            assert(result == false,
                   "Expected config_changed to return false when arms is missing")
        end)

        it("should return false when arms is empty", function()
            turn.app.set_config({
                evidential_api_key = "test-api-key",
                evidential_organization_id = "test-org-id",
                evidential_api_base_url = "https://api.evidential.com/v1/experiments",
                experiment_config = json.encode({
                    experiment_id = "experiment_123",
                    arms = {}
                })
            })
            local result =
                App.on_event(app_config, number, "config_changed", {})
            assert(result == false,
                   "Expected config_changed to return false when arms is empty")
        end)
    end)

    -- Test Journey Events --
    describe("journey_event", function()
        describe("get_assignment_for_contact", function()
            it(
                "should return structured result with arm_id, experiment_id, and journey_uuid",
                function()
                    local journey_data = {
                        function_name = "get_assignment_for_contact",
                        args = {number.msisdn},
                        chat_uuid = "chat-123"
                    }

                    turn.test.mock_http(
                        "experiments/experiment_123/assignments/%+1234567890", {
                            method = "GET",
                            status = 200,
                            body = json.encode({assignment = {arm_id = "arm_a"}})
                        })

                    local status, result =
                        App.on_event(app_config, number, "journey_event",
                                     journey_data)
                    local contact = turn.contacts.find({msisdn = number.msisdn})
                    assert(contact.details.experiment_id == "experiment_123",
                           "Expected experiment_id field to be set on contact")
                    assert(contact.details.assignment_arm_id == "arm_a",
                           "Expected assignment_arm_id field to be set on contact")
                    assert(status == "continue",
                           "Expected journey event to continue")
                    assert(result.assignment == "arm_a",
                           "Expected arm_id in result")
                    assert(result.experiment_id == "experiment_123",
                           "Expected experiment_id in result")
                    assert(result.journey_uuid == "journey-1",
                           "Expected journey_uuid resolved from config")
                end)

            it(
                "should not update contact fields when the update_config is set to false",
                function()
                    local journey_data = {
                        function_name = "get_assignment_for_contact",
                        args = {number.msisdn, false},
                        chat_uuid = "chat-123"
                    }

                    turn.test.mock_http(
                        "experiments/experiment_123/assignments/%+1234567890", {
                            method = "GET",
                            status = 200,
                            body = json.encode({assignment = {arm_id = "arm_a"}})
                        })

                    local status, result =
                        App.on_event(app_config, number, "journey_event",
                                     journey_data)
                    local contact = turn.contacts.find({msisdn = number.msisdn})
                    assert(contact.details.experiment_id == nil,
                           "Expected experiment_id field to not be set on contact")
                    assert(contact.details.assignment_arm_id == nil,
                           "Expected assignment_arm_id field to not be set on contact")
                    assert(status == "continue",
                           "Expected journey event to continue")
                    assert(result.assignment == "arm_a",
                           "Expected arm_id in result")
                end)

            it("should return error when Evidential API fails", function()
                local journey_data = {
                    function_name = "get_assignment_for_contact",
                    args = {number.msisdn},
                    chat_uuid = "chat-123"
                }

                turn.test.mock_http(
                    "experiments/experiment_123/assignments/%+1234567890", {
                        method = "GET",
                        status = 500,
                        body = "Internal Server Error"
                    })

                local status, result = App.on_event(app_config, number,
                                                    "journey_event",
                                                    journey_data)
                assert(status == "error", "Expected error status on API failure")
            end)

            it("should return error when arm_id is not in config", function()
                local journey_data = {
                    function_name = "get_assignment_for_contact",
                    args = {number.msisdn},
                    chat_uuid = "chat-123"
                }

                turn.test.mock_http(
                    "experiments/experiment_123/assignments/%+1234567890", {
                        method = "GET",
                        status = 200,
                        body = json.encode(
                            {assignment = {arm_id = "arm_unknown"}})
                    })

                local status, result = App.on_event(app_config, number,
                                                    "journey_event",
                                                    journey_data)
                assert(status == "error",
                       "Expected error status for unmapped arm")
                assert(
                    result == "Received unknown arm_id from API: arm_unknown",
                    "Expected error message for unmapped arm")
            end)

        end)

        describe("post_outcome_for_contact", function()
            it("should post outcome to Evidential API", function()
                local journey_data = {
                    function_name = "post_outcome_for_contact",
                    args = {number.msisdn, 0.},
                    chat_uuid = "chat-123"
                }

                turn.test.mock_http(
                    "experiments/experiment_123/assignments/%+1234567890/outcome",
                    {
                        method = "POST",
                        status = 200,
                        body = json.encode({status = "recorded"})
                    })

                local status, result = App.on_event(app_config, number,
                                                    "journey_event",
                                                    journey_data)
                assert(status == "continue",
                       "Expected journey event to continue")
                assert(result.outcome_response ~= nil,
                       "Expected outcome_response in result")
            end)

            it("should return error when Evidential API fails", function()
                local journey_data = {
                    function_name = "post_outcome_for_contact",
                    args = {number.msisdn, 0.},
                    chat_uuid = "chat-123"
                }

                turn.test.mock_http(
                    "experiments/experiment_123/assignments/%+1234567890/outcome",
                    {
                        method = "POST",
                        status = 500,
                        body = "Internal Server Error"
                    })

                local status, result = App.on_event(app_config, number,
                                                    "journey_event",
                                                    journey_data)
                assert(status == "error", "Expected error status on API failure")
            end)

        end)

        describe("route_to_experiment", function()
            it("should route contact to arm journey", function()
                local journey_data = {
                    function_name = "route_to_experiment",
                    args = {number.msisdn},
                    chat_uuid = "chat-123"
                }

                turn.test.mock_http(
                    "experiments/experiment_123/assignments/%+1234567890", {
                        method = "GET",
                        status = 200,
                        body = json.encode({
                            assignment = {arm_id = "arm_a"},
                            experiment_id = "experiment_123",
                            journey_uuid = "journey-1"
                        })
                    })

                local status, result = App.on_event(app_config, number,
                                                    "journey_event",
                                                    journey_data)
                assert(status == "continue", "Expected routing to succeed")
                assert(result.routed == true, "Expected routed flag to be true")
                assert(result.arm_id == "arm_a", "Expected arm_id in result")
            end)

            it("should return error when Evidential API fails", function()
                local journey_data = {
                    function_name = "route_to_experiment",
                    args = {number.msisdn},
                    chat_uuid = "chat-123"
                }

                turn.test.mock_http(
                    "experiments/experiment_123/assignments/%+1234567890", {
                        method = "GET",
                        status = 500,
                        body = "Internal Server Error"
                    })

                local status, result = App.on_event(app_config, number,
                                                    "journey_event",
                                                    journey_data)
                assert(status == "error", "Expected error status on API failure")
            end)

            it("should return error for unknown journey function", function()
                local journey_data = {
                    function_name = "nonexistent_function",
                    args = {"arg1"},
                    chat_uuid = "chat-123"
                }

                local status, result = App.on_event(app_config, number,
                                                    "journey_event",
                                                    journey_data)
                assert(status == "error", "Expected error for unknown function")
            end)

        end)
    end)
end)

