-- spec/test_app_spec.lua
-- Generated test file for test_app
--
-- TESTING GUIDE:
-- This file demonstrates common testing patterns for Turn.io Lua apps.
-- For complete testing API reference, visit:
-- https://whatsapp.turn.io/docs
--
-- Quick Tips:
-- - Use turn.test.reset() in before() to start each test with clean state
-- - Mock HTTP calls with turn.test.mock_http(request, response)
-- - Mock app calls with turn.test.mock_app_call(app, event, response)
-- - Verify HTTP calls with turn.test.assert_http_called(request)
-- - Verify app calls with turn.test.assert_app_called(app, event, data)

local lester = require('lester')
local turn = require('turn')
local json = turn.json  -- JSON encoding/decoding from turn module
local App = require('test_app')

local describe, it, before = lester.describe, lester.it, lester.before

describe("test_app", function()
  local app_config
  local number

  before(function()
    -- TESTING TIP: Reset state before each test
    -- This clears all mocks and provides fresh test data:
    -- - 2 test contacts (contact-1, contact-2)
    -- - 2 test journeys (journey-1, journey-2)
    turn.test.reset()

    app_config = {
      uuid = "test-app-uuid",
      config = {}
    }

    number = {
      id = "123",
      vname = "+1234567890"
    }
  end)

  describe("install event", function()
    it("should handle installation", function()
      local result = App.on_event(app_config, number, "install", {})
      assert(result == true, "Expected install to return true")

      -- Verify contact subscriptions were set
      local subs = turn.app.get_contact_subscriptions()
      assert(#subs > 0, "Expected contact subscriptions to be set")
    end)
  end)

  describe("uninstall event", function()
    it("should handle uninstallation", function()
      local result = App.on_event(app_config, number, "uninstall", {})
      assert(result == true, "Expected uninstall to return true")
    end)
  end)

  describe("journey_event", function()
    it("should handle journey hello function", function()
      local journey_data = {
        function_name = "hello",
        args = {},
        chat_uuid = "chat-123"
      }

      local status, result = App.on_event(app_config, number, "journey_event", journey_data)
      assert(status == "continue", "Expected status to be 'continue'")
      assert(result.message ~= nil, "Expected result to have message")
    end)

    it("should return error for unknown journey function", function()
      local journey_data = {
        function_name = "unknown_function",
        args = {},
        chat_uuid = "chat-123"
      }

      local status, error = App.on_event(app_config, number, "journey_event", journey_data)
      assert(status == "error", "Expected status to be 'error'")
    end)

    -- EXAMPLE: Testing with HTTP mocking
    -- Uncomment and adapt this example if your app makes HTTP requests
    --[[
    it("should make external API call", function()
      -- Mock the external API
      turn.test.mock_http(
        {
          method = "GET",
          url = "https://api.example.com/data"
        },
        {
          status = 200,
          headers = {["content-type"] = "application/json"},
          body = json.encode({success = true, data = "test"})
        }
      )

      -- Trigger your app code that makes the HTTP call
      local status, result = App.on_event(app_config, number, "journey_event", {
        function_name = "fetch_data",
        args = {}
      })

      -- Verify the HTTP call was made
      turn.test.assert_http_called({
        method = "GET",
        url = "https://api.example.com/data"
      })

      -- Verify the result
      assert(status == "continue")
      assert(result.data == "test")
    end)
    --]]

    -- EXAMPLE: Testing error handling
    -- Uncomment and adapt this example to test error scenarios
    --[[
    it("should handle API errors gracefully", function()
      -- Mock a failed API response
      turn.test.mock_http(
        {
          method = "POST",
          url = "https://api.example.com/process"
        },
        {
          status = 500,
          body = "Internal Server Error"
        }
      )

      local status, result = App.on_event(app_config, number, "journey_event", {
        function_name = "process_data",
        args = {}
      })

      -- Verify error was handled
      assert(status == "continue" or status == "error")
      assert(result.error ~= nil, "Expected error to be present")
    end)
    --]]

    -- EXAMPLE: Testing app-to-app calls
    -- Uncomment and adapt if your app calls other apps
    --[[
    it("should call other app", function()
      -- Mock the app call
      turn.test.mock_app_call("other_app", "some_action", {
        success = true,
        result = "mocked result"
      })

      local status, result = App.on_event(app_config, number, "journey_event", {
        function_name = "use_other_app",
        args = {}
      })

      -- Verify the app was called
      turn.test.assert_app_called("other_app", "some_action")

      -- Verify result
      assert(status == "continue")
      assert(result.result == "mocked result")
    end)
    --]]

    -- EXAMPLE: Testing with configuration
    -- Uncomment and adapt if your app uses configuration
    --[[
    it("should use configuration values", function()
      -- Set test configuration
      turn.test.set_config("api_key", "test-key-123")
      turn.test.set_config("api_url", "https://test.api.com")

      -- Your app code that uses config
      local status, result = App.on_event(app_config, number, "journey_event", {
        function_name = "configured_action",
        args = {}
      })

      -- Verify config was used correctly
      assert(status == "continue")
    end)
    --]]

    -- EXAMPLE: Testing async operations with leases
    -- Uncomment and adapt if your app uses async operations
    --[[
    it("should handle async operation", function()
      -- Start async operation
      local status, result = App.on_event(app_config, number, "journey_event", {
        function_name = "start_async",
        args = {callback_url = "https://example.com/callback"}
      })

      -- Should return wait action
      assert(status == "wait", "Expected wait action for async operation")
      assert(result.lease_id ~= nil, "Expected lease_id")

      -- Simulate callback data received
      turn.test.add_lease({
        lease_id = result.lease_id,
        data = {
          status = "completed",
          result = "async result"
        }
      })

      -- Resume processing
      local resume_status, resume_result = App.on_event(app_config, number, "journey_event", {
        function_name = "resume_async",
        lease_id = result.lease_id
      })

      -- Verify resumed successfully
      assert(resume_status == "continue")
      assert(resume_result.result == "async result")
    end)
    --]]
  end)

  describe("http_request", function()
    it("should handle health check endpoint", function()
      local request_data = {
        method = "GET",
        path_info = {"health"},
        request_path = "/health"
      }

      local result, response = App.on_event(app_config, number, "http_request", request_data)
      assert(result == true, "Expected http_request to return true")
      assert(response.status == 200, "Expected status 200")
    end)

    -- Add more http_request tests here if your app has HTTP endpoints
  end)

  -- DEBUGGING TIP: If tests are failing, uncomment these debugging helpers
  --[[
  it("DEBUG: inspect HTTP requests", function()
    -- Trigger code that makes HTTP requests
    App.on_event(app_config, number, "journey_event", {
      function_name = "some_function",
      args = {}
    })

    -- See what HTTP requests were made
    local requests = turn.test.get_http_requests()
    for i, req in ipairs(requests) do
      turn.logger.info("HTTP Request " .. i .. ":")
      turn.logger.info("  Method: " .. req.method)
      turn.logger.info("  URL: " .. req.url)
      turn.logger.info("  Body: " .. (req.body or "none"))
    end
  end)

  it("DEBUG: inspect app calls", function()
    -- Trigger code that calls other apps
    App.on_event(app_config, number, "journey_event", {
      function_name = "some_function",
      args = {}
    })

    -- See what app calls were made
    local calls = turn.test.get_app_calls()
    for i, call in ipairs(calls) do
      turn.logger.info("App Call " .. i .. ":")
      turn.logger.info("  App: " .. call.app_name)
      turn.logger.info("  Event: " .. call.event_name)
      turn.logger.info("  Data: " .. json.encode(call.data))
    end
  end)
  --]]
end)

-- Report test results and exit with appropriate code
lester.report()
lester.exit()
