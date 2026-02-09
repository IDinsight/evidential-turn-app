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
    turn.test.reset()

    app_config = {
      uuid = "test-app-uuid",
      config = {
        evidential_api_key = "your-api-key",
        evidential_organization_id = "your-organization-id",
        evidential_api_base_url = "https://api.evidential.com/v1"
      }
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
      -- assert(result.contact_fields.created == 2, "Expected 2 contact fields to be created")

      -- Verify app config was updated with manifest

      local config = turn.app.get_config()
      local required_fields = {"evidential_api_key", "evidential_organization_id", "evidential_api_base_url"}
      for _, field in ipairs(required_fields) do
        assert(config[field] ~= nil, "Expected config to include " .. field)
      end
    end)
  end)

  describe("uninstall event", function()
    it("should handle uninstallation", function()
      local result = App.on_event(app_config, number, "uninstall", {})
      assert(result == true, "Expected uninstall to return true")
    end)
  end)


  describe("journey_event", function()
    it("should handle updating contact fields", function()
      local journey_data = {
        function_name = "update_contact_fields",
        args = {"experiment_123", "assigned_arm_123"},
        chat_uuid = "chat-123"
      }
      local status, result = App.on_event(app_config, number, "journey_event", journey_data)
      assert(status == "continue", "Expected status to be 'continue'")
      assert(result.message == "Contact fields updated successfully", "Expected success message")
      local contact_subscriptions = turn.app.get_contact_subscriptions()
      assert(contact_subscriptions["experiment_id"] == "experiment_123", "Expected experiment_id to be updated in contact subscriptions")
      assert(contact_subscriptions["assignment_arm_id"] == "assigned_arm_123", "Expected assignment_arm_id to be updated in contact subscriptions")
    end)
  end)
end)

-- Report test results and exit with appropriate code
lester.report()
lester.exit()
