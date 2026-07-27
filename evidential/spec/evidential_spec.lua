local lester = require('lester')
local turn = require('turn')
local json = turn.json -- JSON encoding/decoding from turn module
local App = require('evidential')
local ConfigChangedEvents = require('lib/config_changed_events')

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

    describe("config_changed_events (unit)", function()

        describe("redact_config_secrets", function()
            it("should redact both the api key and the webhook auth token",
               function()
                local raw = {
                    evidential_api_key = "abcdefgh-secret-key",
                    evidential_webhook_auth_token = "12345678-secret-token",
                    evidential_webhook_id = "webhook-123"
                }
                local safe = ConfigChangedEvents.redact_config_secrets(raw)

                assert(safe.evidential_api_key == "abcdefgh****",
                       "Expected api key to be redacted to first 8 chars + ****; got: " ..
                           tostring(safe.evidential_api_key))
                assert(safe.evidential_webhook_auth_token == "12345678****",
                       "Expected webhook auth token to be redacted; got: " ..
                           tostring(safe.evidential_webhook_auth_token))
                assert(safe.evidential_webhook_id == "webhook-123",
                       "Expected non-secret field to be preserved")
                assert(raw.evidential_api_key == "abcdefgh-secret-key",
                       "Expected original config to be left unmutated")
                assert(raw.evidential_webhook_auth_token ==
                           "12345678-secret-token",
                       "Expected original webhook token to be left unmutated")
            end)
        end)

        describe("journeys_changed", function()
            it(
                "should return true and write both globals when the journey list changed",
                function()
                    local changed = ConfigChangedEvents.journeys_changed()
                    assert(changed == true,
                           "Expected journeys_changed to report a change on first run")

                    local snapshot = turn.data.dictionary.get_global(
                                         "journeys_snapshot")
                    local last_checked =
                        turn.data.dictionary.get_global("journeys_last_checked")
                    assert(snapshot ~= nil,
                           "Expected journeys_snapshot global to be written")
                    assert(snapshot.journeys ~= nil and #snapshot.journeys > 0,
                           "Expected the snapshot to contain the current journeys")
                    assert(last_checked ~= nil and
                               last_checked.last_snapshot_time ~= nil,
                           "Expected journeys_last_checked timestamp to be written")
                end)

            it(
                "should return false and not update the timestamp when the journey list is unchanged",
                function()
                    ConfigChangedEvents.journeys_changed()

                    local old_time = os.time() - 1000
                    turn.data.dictionary.set_global("journeys_last_checked", {
                        last_snapshot_time = old_time
                    })

                    local changed = ConfigChangedEvents.journeys_changed()
                    assert(changed == false,
                           "Expected journeys_changed to report no change for an identical journey list")

                    local last_checked =
                        turn.data.dictionary.get_global("journeys_last_checked")
                    assert(last_checked.last_snapshot_time == old_time,
                           "Expected journeys_last_checked to remain unchanged when nothing changed")
                end)

            it(
                "should skip the check (return false) when checked within the throttle interval",
                function()
                    turn.data.dictionary.set_global("journeys_last_checked", {
                        last_snapshot_time = os.time()
                    })

                    local changed = ConfigChangedEvents.journeys_changed()
                    assert(changed == false,
                           "Expected journeys_changed to skip within the throttle interval")
                    assert(
                        turn.data.dictionary.get_global("journeys_snapshot") ==
                            nil,
                        "Expected no snapshot to be written when the check is throttled")
                end)
        end)

        describe("notify_refresh_journeys", function()
            it("should POST to the webhook and return true on a 2xx response",
               function()
                local app_cfg = {
                    evidential_webhook_id = "wh-123",
                    evidential_webhook_auth_token = "secret-token"
                }

                turn.test.mock_http("webhook/wh%-123/config%-updated", {
                    method = "POST",
                    status = 200,
                    body = json.encode({status = "ok"})
                })

                local ok = ConfigChangedEvents.notify_refresh_journeys(app_cfg)
                assert(ok == true,
                       "Expected notify_refresh_journeys to return true on 2xx")

                local requests = turn.test.get_http_requests()
                local found = false
                for _, req in ipairs(requests) do
                    if req.method == "POST" and
                        req.url:find("webhook/wh-123/config-updated", 1, true) then
                        found = true
                    end
                end
                assert(found,
                       "Expected a POST to the config-updated webhook URL: " ..
                           json.encode(requests))
            end)

            it("should return nil and an error message on a non-2xx response",
               function()
                local app_cfg = {
                    evidential_webhook_id = "wh-123",
                    evidential_webhook_auth_token = "secret-token"
                }

                turn.test.mock_http("webhook/wh%-123/config%-updated", {
                    method = "POST",
                    status = 500,
                    body = "Internal Server Error"
                })

                local ok, err = ConfigChangedEvents.notify_refresh_journeys(
                                    app_cfg)
                assert(ok == nil,
                       "Expected notify_refresh_journeys to return nil on failure")
                assert(err ==
                           "Failed to notify Evidential webhook for refresh-journeys: HTTP 500",
                       "Expected the HTTP 500 error message; got: " ..
                           tostring(err))
            end)
        end)

        describe("sync_config", function()
            it(
                "should preserve admin-set values and fill missing keys from the manifest",
                function()
                    turn.app.update_config({evidential_api_key = "admin-key"})

                    local ok = ConfigChangedEvents.sync_config()
                    assert(ok == true, "Expected sync_config to return true")

                    local config = turn.app.get_config()
                    assert(config.evidential_api_key == "admin-key",
                           "Expected the admin-set api key to take precedence over the manifest default")
                    assert(config.evidential_webhook_id == "your-webhook-id",
                           "Expected the missing webhook id to be filled from the manifest")
                    assert(config.evidential_webhook_auth_token ==
                               "your-webhook-auth-token",
                           "Expected the missing webhook auth token to be filled from the manifest")
                end)
        end)
    end)

    describe("config_changed event", function()
        local function webhook_was_notified()
            for _, req in ipairs(turn.test.get_http_requests()) do
                local url = req.url or ""
                if req.method == "POST" and url:find("config-updated", 1, true) then
                    return true
                end
            end
            return false
        end

        it(
            "should notify the refresh-journeys webhook when the journey list has changed",
            function()
                turn.app.update_config({
                    evidential_api_key = "your-api-key",
                    evidential_webhook_id = "wh-123",
                    evidential_webhook_auth_token = "secret-token"
                })
                turn.test.mock_http("webhook/wh%-123/config%-updated", {
                    method = "POST",
                    status = 200,
                    body = json.encode({status = "ok"})
                })

                local result = App.on_event(app_config, number,
                                            "config_changed", {})
                assert(result == true, "Expected config_changed to return true")
                assert(webhook_was_notified(),
                       "Expected the refresh-journeys webhook to be notified: " ..
                           json.encode(turn.test.get_http_requests()))
            end)

        it("should not notify the webhook when the journeys check is throttled",
           function()
            turn.app.update_config({
                evidential_api_key = "your-api-key",
                evidential_webhook_id = "wh-123",
                evidential_webhook_auth_token = "secret-token"
            })

            turn.data.dictionary.set_global("journeys_last_checked",
                                            {last_snapshot_time = os.time()})

            local result =
                App.on_event(app_config, number, "config_changed", {})
            assert(result == true, "Expected config_changed to return true")
            assert(not webhook_was_notified(),
                   "Expected no webhook notification when the check is throttled")
        end)

        it(
            "should sync config (admin values win, missing keys filled) and return true",
            function()
                turn.app.update_config({evidential_api_key = "admin-key"})
                turn.test.mock_http("webhook/[^/]+/config%-updated", {
                    method = "POST",
                    status = 200,
                    body = json.encode({status = "ok"})
                })

                local result = App.on_event(app_config, number,
                                            "config_changed", {})
                assert(result == true,
                       "Expected config_changed to return true on success")

                local config = turn.app.get_config()
                assert(config.evidential_api_key == "admin-key",
                       "Expected the admin api key to be preserved after sync")
                assert(config.evidential_webhook_id == "your-webhook-id",
                       "Expected the manifest webhook id to be filled during sync")
            end)
    end)
end)
