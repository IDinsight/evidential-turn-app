-- spec/evidential_spec.lua
local lester = require('lester')
local turn = require('turn')
local json = turn.json
local App = require('evidential')

local describe, it, before = lester.describe, lester.it, lester.before

describe("evidential", function()
    local app_config
    local number

    before(function()
        turn.test.reset()

        app_config = {
            uuid = "evidential-app-uuid",
            config = {
                evidential_api_key = "test-api-key",
                evidential_organization_id = "test-org-id",
                evidential_api_base_url = "https://api.evidential.com/v1/experiments",
                experiment_config = json.encode({
                    experiment_name = "Test Experiment",
                    experiment_id = "experiment_123",
                    arms = {
                        arm_abc = "journey-uuid-1",
                        arm_def = "journey-uuid-2"
                    }
                })
            }
        }
        turn.test.set_config(app_config.config)

        number = {id = "123", msisdn = "+1234567890"}

        -- Install first (creates journey mapping), then config_changed
        -- populates the local data dictionary for journey events
        App.on_event(app_config, number, "install", {})
        App.on_event(app_config, number, "config_changed", {})
    end)

    describe("install event", function()
        it("should handle installation", function()
            local result = App.on_event(app_config, number, "install", {})
            assert(result == true, "Expected install to return true")

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
            local result = App.on_event(app_config, number, "uninstall", {})
            assert(result == true, "Expected uninstall to return true")
        end)
    end)

    describe("config_changed event", function()
        it("should return true for valid config", function()
            local result = App.on_event(app_config, number, "config_changed", {})
            assert(result == true, "Expected config_changed to return true for valid config")
        end)

        it("should write experiment config to data dictionary", function()
            App.on_event(app_config, number, "config_changed", {})

            -- Check global dictionary (used by journey event handlers)
            local data = turn.data.dictionary.get_global("evidential_experiment")
            assert(data ~= nil, "Expected global data dictionary entry to exist")
            assert(data.experiment_id == "experiment_123", "Expected experiment_id in dictionary")
            assert(data.arms ~= nil, "Expected arms in dictionary")
            assert(data.arms.arm_abc == "journey-uuid-1", "Expected arm mapping in dictionary")

            -- Check local dictionary (available as @local.evidential_experiment.* in Stacks)
            local journey_mapping = turn.app.get_journey_mapping()
            for _, journey_uuid in pairs(journey_mapping) do
                local local_data = turn.data.dictionary.get_local(journey_uuid, "evidential_experiment")
                assert(local_data ~= nil, "Expected local data dictionary entry to exist")
                assert(local_data.experiment_id == "experiment_123", "Expected experiment_id in local dictionary")
            end
        end)

        it("should return false when experiment_config is missing", function()
            turn.app.set_config({
                evidential_api_key = "test-api-key",
                evidential_organization_id = "test-org-id",
                evidential_api_base_url = "https://api.evidential.com/v1/experiments"
            })
            local result = App.on_event(app_config, number, "config_changed", {})
            assert(result == false, "Expected config_changed to return false when experiment_config is missing")
        end)

        it("should return false for malformed JSON in experiment_config", function()
            turn.app.set_config({
                evidential_api_key = "test-api-key",
                evidential_organization_id = "test-org-id",
                evidential_api_base_url = "https://api.evidential.com/v1/experiments",
                experiment_config = "not valid json{{"
            })
            local result = App.on_event(app_config, number, "config_changed", {})
            assert(result == false, "Expected config_changed to return false for malformed JSON")
        end)

        it("should return false when experiment_id is missing", function()
            turn.app.set_config({
                evidential_api_key = "test-api-key",
                evidential_organization_id = "test-org-id",
                evidential_api_base_url = "https://api.evidential.com/v1/experiments",
                experiment_config = json.encode({
                    arms = {arm_abc = "journey-uuid-1"}
                })
            })
            local result = App.on_event(app_config, number, "config_changed", {})
            assert(result == false, "Expected config_changed to return false when experiment_id is missing")
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
            local result = App.on_event(app_config, number, "config_changed", {})
            assert(result == false, "Expected config_changed to return false when arms is missing")
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
            local result = App.on_event(app_config, number, "config_changed", {})
            assert(result == false, "Expected config_changed to return false when arms is empty")
        end)
    end)

    describe("journey_event", function()
        describe("route_to_experiment", function()
            it("should route contact to arm journey", function()
                -- Register a contact findable by msisdn
                turn.test.add_contact({
                    uuid = "test-route-contact",
                    details = {msisdn = number.msisdn, name = "Test Contact"}
                })

                -- Register the arm journey so turn.journeys.start() can find it
                turn.test.add_journey({
                    uuid = "journey-uuid-1",
                    name = "Arm ABC Journey",
                    enabled = true
                })

                local journey_data = {
                    function_name = "route_to_experiment",
                    args = {number.msisdn},
                    chat_uuid = "chat-123"
                }

                turn.test.mock_http("experiments/experiment_123/assignments/%+1234567890", {
                    method = "GET",
                    status = 200,
                    body = json.encode({assignment = {arm_id = "arm_abc"}})
                })

                local status, result = App.on_event(app_config, number,
                                                    "journey_event", journey_data)
                assert(status == "continue", "Expected routing to succeed")
                assert(result.routed == true, "Expected routed flag to be true")
                assert(result.arm_id == "arm_abc", "Expected arm_id in result")
            end)

            it("should return error when Evidential API fails", function()
                local journey_data = {
                    function_name = "route_to_experiment",
                    args = {number.msisdn},
                    chat_uuid = "chat-123"
                }

                turn.test.mock_http("experiments/experiment_123/assignments/%+1234567890", {
                    method = "GET",
                    status = 500,
                    body = "Internal Server Error"
                })

                local status, result = App.on_event(app_config, number,
                                                    "journey_event", journey_data)
                assert(status == "error", "Expected error status on API failure")
            end)

            it("should return error when arm_id has no configured journey", function()
                local journey_data = {
                    function_name = "route_to_experiment",
                    args = {number.msisdn},
                    chat_uuid = "chat-123"
                }

                -- Return an arm_id that's not in the config's arms map
                turn.test.mock_http("experiments/experiment_123/assignments/%+1234567890", {
                    method = "GET",
                    status = 200,
                    body = json.encode({assignment = {arm_id = "arm_unknown"}})
                })

                local status, result = App.on_event(app_config, number,
                                                    "journey_event", journey_data)
                assert(status == "error", "Expected error for unmapped arm")
            end)
        end)

        it("should return error for unknown journey function", function()
            local journey_data = {
                function_name = "nonexistent_function",
                args = {"arg1"},
                chat_uuid = "chat-123"
            }

            local status, result = App.on_event(app_config, number,
                                                "journey_event", journey_data)
            assert(status == "error", "Expected error for unknown function")
        end)

        describe("get_assignment_for_contact", function()
            it("should return structured result with arm_id, experiment_id, and journey_uuid", function()
                local journey_data = {
                    function_name = "get_assignment_for_contact",
                    args = {number.msisdn},
                    chat_uuid = "chat-123"
                }

                turn.test.mock_http("experiments/experiment_123/assignments/%+1234567890", {
                    method = "GET",
                    status = 200,
                    body = json.encode({assignment = {arm_id = "arm_abc"}})
                })

                local status, result = App.on_event(app_config, number, "journey_event", journey_data)
                assert(status == "continue", "Expected journey event to continue")
                assert(result.assignment == "arm_abc", "Expected arm_id in result")
                assert(result.experiment_id == "experiment_123", "Expected experiment_id in result")
                assert(result.journey_uuid == "journey-uuid-1", "Expected journey_uuid resolved from config")
            end)

            it("should return error when Evidential API fails", function()
                local journey_data = {
                    function_name = "get_assignment_for_contact",
                    args = {number.msisdn},
                    chat_uuid = "chat-123"
                }

                turn.test.mock_http("experiments/experiment_123/assignments/%+1234567890", {
                    method = "GET",
                    status = 500,
                    body = "Internal Server Error"
                })

                local status, result = App.on_event(app_config, number,
                                                    "journey_event", journey_data)
                assert(status == "error", "Expected error status on API failure")
            end)

            it("should return nil journey_uuid when arm_id is not in config", function()
                local journey_data = {
                    function_name = "get_assignment_for_contact",
                    args = {number.msisdn},
                    chat_uuid = "chat-123"
                }

                turn.test.mock_http("experiments/experiment_123/assignments/%+1234567890", {
                    method = "GET",
                    status = 200,
                    body = json.encode({assignment = {arm_id = "arm_unknown"}})
                })

                local status, result = App.on_event(app_config, number,
                                                    "journey_event", journey_data)
                assert(status == "continue", "Expected continue even with unmapped arm")
                assert(result.assignment == "arm_unknown", "Expected arm_id in result")
                assert(result.journey_uuid == nil, "Expected nil journey_uuid for unmapped arm")
            end)
        end)

        describe("post_outcome_for_contact", function()
            it("should post outcome to Evidential API", function()
                local journey_data = {
                    function_name = "post_outcome_for_contact",
                    args = {number.msisdn, 0.},
                    chat_uuid = "chat-123"
                }

                turn.test.mock_http("experiments/experiment_123/assignments/%+1234567890/outcome", {
                    method = "POST",
                    status = 200,
                    body = json.encode({status = "recorded"})
                })

                local status, result = App.on_event(app_config, number,
                                                    "journey_event", journey_data)
                assert(status == "continue", "Expected journey event to continue")
                assert(result.outcome_response ~= nil, "Expected outcome_response in result")
            end)

            it("should return error when Evidential API fails", function()
                local journey_data = {
                    function_name = "post_outcome_for_contact",
                    args = {number.msisdn, 0.},
                    chat_uuid = "chat-123"
                }

                turn.test.mock_http("experiments/experiment_123/assignments/%+1234567890/outcome", {
                    method = "POST",
                    status = 500,
                    body = "Internal Server Error"
                })

                local status, result = App.on_event(app_config, number,
                                                    "journey_event", journey_data)
                assert(status == "error", "Expected error status on API failure")
            end)
        end)
    end)
end)

lester.report()
lester.exit()
