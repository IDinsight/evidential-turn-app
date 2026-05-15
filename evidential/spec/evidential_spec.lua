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
            config = {evidential_api_key = "your-api-key"}
        }

        turn.app.update_config(app_config.config)

        number = {id = "123"}

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

        turn.data.dictionary.set_global("evidential_experiment_experiment_123",
                                        {
            experiment_id = "experiment_123",
            arm_journey_map = {arm_a = "journey-1", arm_b = "journey-2"}
        }, {replace = true})
        turn.data.dictionary.set_global("evidential_experiment_index", {
            ["evidential_experiment_experiment_123"] = true
        }, {append = true})

        -- Set up test contact
        global_contact = {
            uuid = "test-route-contact",
            details = {
                urn = "1234567899",
                name = "Test Contact",
                uuid = "test-route-contact"
            }
        }
        turn.test.add_contact(global_contact)
        -- Mock the get function
        turn.contacts.get = function(uuid)
            if uuid == global_contact.uuid then
                return global_contact, true
            else
                return nil, false
            end
        end

        -- Set up test journeys for arms
        for i = 1, 3 do
            turn.test.add_journey({
                uuid = "journey-" .. i,
                name = "Journey " .. i,
                enabled = true
            })
        end

        -- Default 200 mock for the Evidential turn-app-config fetch.
        -- journey_event handlers call set_experiment_config -> HTTP on every
        -- invocation, so all journey_event tests rely on this mock.
        turn.test.mock_http(
            "integrations/experiments/experiment_123/turn%-app%-config", {
                method = "GET",
                status = 200,
                body = json.encode({
                    experiment_id = "experiment_123",
                    experiment_name = "Test Experiment",
                    arm_journey_map = {arm_a = "journey-1", arm_b = "journey-2"}
                })
            })

    end)

    describe("install event", function()
        it("should handle installation", function()
            local result = App.on_event(app_config, number, "install", {})
            assert(result == true, "Expected install to return true")
            -- assert(result.contact_fields.created == 2, "Expected 2 contact fields to be created")

            -- Verify app config was updated with manifest

            local config = turn.app.get_config()
            local required_fields = {"evidential_api_key"}
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

            local experiment_data = turn.data.dictionary.get_global(
                                        "evidential_experiment_experiment_123")
            local experiment_index = turn.data.dictionary.get_global(
                                         "evidential_experiment_index")
            assert(experiment_data == nil,
                   "Expected experiment data to be deleted from data dictionary")
            assert(experiment_index == nil,
                   "Expected experiment index to be deleted from data dictionary")

        end)
    end)

    describe("config changes on journey_event", function()
        it("should fetch and store experiment config from the Evidential API",
           function()
            local new_config = {
                uuid = app_config.uuid,
                config = {evidential_api_key = 'new-api-key'}
            }
            local journey_data = {
                function_name = "get_assignment_for_contact",
                args = {global_contact.details.urn, "experiment_456", true},
                chat_uuid = "chat-123",
                contact_uuid = global_contact.uuid
            }

            turn.test.mock_http(
                "integrations/experiments/experiment_456/turn%-app%-config", {
                    method = "GET",
                    status = 200,
                    body = json.encode({
                        experiment_id = "experiment_456",
                        experiment_name = "New Experiment",
                        arm_journey_map = {
                            arm_a = "journey-1",
                            arm_b = "journey-2"
                        }
                    })
                })

            turn.app.update_config(new_config.config) -- Ensure config is updated before triggering event

            -- We don't care about the result here, we just want to check that the config was fetched and stored correctly,
            -- which happens at the start of the journey_event handler
            App.on_event(new_config, number, "journey_event", journey_data)

            local config = turn.app.get_config()
            assert(config.evidential_api_key == "new-api-key",
                   "Expected API key to be updated in config")

            local experiment_data = turn.data.dictionary.get_global(
                                        "evidential_experiment_experiment_456")
            assert(experiment_data ~= nil,
                   "Expected experiment data to be set in data dictionary")
            assert(experiment_data.experiment_id == "experiment_456",
                   "Expected experiment_id to match API response")
            assert(experiment_data.experiment_name == "New Experiment",
                   "Expected experiment_name to be stored from API response")
            assert(experiment_data.arm_journey_map.arm_a == "journey-1",
                   "Expected arm_a to map to journey-1")
            assert(experiment_data.arm_journey_map.arm_b == "journey-2",
                   "Expected arm_b to map to journey-2")

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

        it("should fail when the Evidential API returns a non-200 response",
           function()
            local new_config = {
                uuid = app_config.uuid,
                config = {evidential_api_key = "new-api-key"}
            }
            local journey_data = {
                function_name = "get_assignment_for_contact",
                args = {global_contact.details.urn, "experiment_456", true},
                chat_uuid = "chat-123",
                contact_uuid = global_contact.uuid
            }

            turn.test.mock_http(
                "integrations/experiments/experiment_456/turn%-app%-config",
                {method = "GET", status = 500, body = "Internal Server Error"})

            turn.app.update_config(new_config.config)
            local status, result = App.on_event(new_config, number,
                                                "journey_event", journey_data)
            assert(status == "error", "Expected error status on API failure")
        end)

        it("should fail when the API response body is empty/null", function()
            local new_config = {
                uuid = app_config.uuid,
                config = {evidential_api_key = "new-api-key"}
            }
            local journey_data = {
                function_name = "get_assignment_for_contact",
                args = {global_contact.details.urn, "experiment_456", true},
                chat_uuid = "chat-123",
                contact_uuid = global_contact.uuid
            }

            turn.test.mock_http(
                "integrations/experiments/experiment_456/turn%-app%-config",
                {method = "GET", status = 200, body = "null"})

            turn.app.update_config(new_config.config)
            local status, result = App.on_event(new_config, number,
                                                "journey_event", journey_data)
            assert(status == "error",
                   "Expected error status on empty response body")
        end)

        it("should fail when the API response is missing arm_journey_map",
           function()
            local new_config = {
                uuid = app_config.uuid,
                config = {evidential_api_key = "new-api-key"}
            }
            local journey_data = {
                function_name = "get_assignment_for_contact",
                args = {global_contact.details.urn, "experiment_456", true},
                chat_uuid = "chat-123",
                contact_uuid = global_contact.uuid
            }

            turn.test.mock_http(
                "integrations/experiments/experiment_456/turn%-app%-config", {
                    method = "GET",
                    status = 200,
                    body = json.encode({
                        experiment_id = "experiment_456",
                        experiment_name = "New Experiment"
                    })
                })

            turn.app.update_config(new_config.config)
            local status, result = App.on_event(new_config, number,
                                                "journey_event", journey_data)
            assert(status == "error",
                   "Expected error status when arm_journey_map missing")
        end)

        it("should fail when the API response is missing experiment_id",
           function()
            local new_config = {
                uuid = app_config.uuid,
                config = {evidential_api_key = "new-api-key"}
            }
            local journey_data = {
                function_name = "get_assignment_for_contact",
                args = {global_contact.details.urn, "experiment_456", true},
                chat_uuid = "chat-123",
                contact_uuid = global_contact.uuid
            }

            turn.test.mock_http(
                "integrations/experiments/experiment_456/turn%-app%-config", {
                    method = "GET",
                    status = 200,
                    body = json.encode({
                        experiment_name = "New Experiment",
                        arm_journey_map = {arm_a = "journey-1"}
                    })
                })

            turn.app.update_config(new_config.config)
            local status, result = App.on_event(new_config, number,
                                                "journey_event", journey_data)
            assert(status == "error",
                   "Expected error status when experiment_id missing")
        end)

        it(
            "should fail when arm_journey_map references an unknown journey UUID",
            function()
                local new_config = {
                    uuid = app_config.uuid,
                    config = {evidential_api_key = "new-api-key"}
                }
                local journey_data = {
                    function_name = "get_assignment_for_contact",
                    args = {global_contact.details.urn, "experiment_456", true},
                    chat_uuid = "chat-123",
                    contact_uuid = global_contact.uuid
                }

                turn.test.mock_http(
                    "integrations/experiments/experiment_456/turn%-app%-config",
                    {
                        method = "GET",
                        status = 200,
                        body = json.encode({
                            experiment_id = "experiment_456",
                            experiment_name = "New Experiment",
                            arm_journey_map = {arm_a = "journey-does-not-exist"}
                        })
                    })

                turn.app.update_config(new_config.config)
                local status, result = App.on_event(new_config, number,
                                                    "journey_event",
                                                    journey_data)
                assert(status == "error",
                       "Expected error status when journey UUID is unknown")
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
                        args = {
                            global_contact.details.urn, "experiment_123", true
                        },
                        chat_uuid = "chat-123",
                        contact_uuid = global_contact.uuid
                    }

                    turn.test.mock_http(string.format(
                                            "experiments/experiment_123/assignments/%s",
                                            tostring(global_contact.details.urn)),
                                        {
                        method = "GET",
                        status = 200,
                        body = json.encode({assignment = {arm_id = "arm_a"}})
                    })
                    local status, result =
                        App.on_event(app_config, number, "journey_event",
                                     journey_data)

                    local experiment_data =
                        turn.data.dictionary.get_global(
                            "evidential_experiment_experiment_123")

                    local contact = turn.contacts.find({
                        uuid = global_contact.uuid
                    })

                    assert(experiment_data.experiment_id == "experiment_123",
                           "Expected experiment_id in data dictionary to match API response")
                    assert(experiment_data.arm_journey_map.arm_a == "journey-1",
                           "Expected arm_a to map to journey-1 in data dictionary")
                    assert(experiment_data.arm_journey_map.arm_b == "journey-2",
                           "Expected arm_b to map to journey-2 in data dictionary")
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
                "should not update contact fields when the update_contact_fields is set to false",
                function()
                    local journey_data = {
                        function_name = "get_assignment_for_contact",
                        args = {
                            global_contact.details.urn, "experiment_123", false
                        },
                        chat_uuid = "chat-123",
                        contact_uuid = global_contact.uuid
                    }

                    turn.test.mock_http(string.format(
                                            "experiments/experiment_123/assignments/%s",
                                            tostring(global_contact.details.urn)),
                                        {
                        method = "GET",
                        status = 200,
                        body = json.encode({assignment = {arm_id = "arm_a"}})
                    })

                    local status, result =
                        App.on_event(app_config, number, "journey_event",
                                     journey_data)
                    local contact = turn.contacts.find({
                        uuid = global_contact.uuid
                    })
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
                    args = {global_contact.details.urn, "experiment_123", false},
                    chat_uuid = "chat-123",
                    contact_uuid = global_contact.uuid
                }

                turn.test.mock_http(string.format(
                                        "experiments/experiment_123/assignments/%s",
                                        tostring(global_contact.details.urn)), {
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
                    args = {global_contact.details.urn, "experiment_123", false},
                    chat_uuid = "chat-123",
                    contact_uuid = global_contact.uuid
                }

                turn.test.mock_http(string.format(
                                        "experiments/experiment_123/assignments/%s",
                                        tostring(global_contact.details.urn)), {
                    method = "GET",
                    status = 200,
                    body = json.encode({assignment = {arm_id = "arm_unknown"}})
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
                    args = {global_contact.details.urn, "experiment_123", 0.},
                    chat_uuid = "chat-123",
                    contact_uuid = global_contact.uuid
                }

                turn.test.mock_http(string.format(
                                        "experiments/experiment_123/assignments/%s/outcome",
                                        tostring(global_contact.details.urn)), {
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
                    args = {global_contact.details.urn, "experiment_123", 0.},
                    chat_uuid = "chat-123",
                    contact_uuid = global_contact.uuid
                }

                turn.test.mock_http(string.format(
                                        "experiments/experiment_123/assignments/%s/outcome",
                                        tostring(global_contact.details.urn)), {
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
                    args = {global_contact.details.urn, "experiment_123"},
                    chat_uuid = "chat-123",
                    contact_uuid = global_contact.uuid
                }

                turn.test.mock_http(string.format(
                                        "experiments/experiment_123/assignments/%s",
                                        tostring(global_contact.details.urn)), {
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
                    args = {global_contact.details.urn, "experiment_123"},
                    chat_uuid = "chat-123",
                    contact_uuid = global_contact.uuid
                }

                turn.test.mock_http(string.format(
                                        "experiments/experiment_123/assignments/%s",
                                        tostring(global_contact.details.urn)), {
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
                    args = {"arg1", "experiment_123"},
                    chat_uuid = "chat-123"
                }

                local status, result = App.on_event(app_config, number,
                                                    "journey_event",
                                                    journey_data)
                assert(status == "error", "Expected error for unknown function")
            end)

        end)

        it(
            "should return error when set_experiment_config fails on a journey_event",
            function()
                -- Point the app at an experiment_id that has no turn-app-config
                -- mock. The default Turn HTTP mock returns a body without
                -- experiment_id/arm_journey_map, so set_experiment_config
                -- validation fails and on_event hits the new error path.
                turn.app.update_config({evidential_api_key = "your-api-key"})

                local journey_data = {
                    function_name = "get_assignment_for_contact",
                    args = {global_contact.details.urn, "experiment_unmocked"},
                    chat_uuid = "chat-123"
                }

                local status, result = App.on_event(app_config, number,
                                                    "journey_event",
                                                    journey_data)
                assert(status == "error",
                       "Expected error status when set_experiment_config fails")
                assert(result ==
                           "Invalid experiment config. Check that you have a valid API key and experiment ID.",
                       "Expected specific error message; got: " ..
                           tostring(result))
            end)
    end)
end)
