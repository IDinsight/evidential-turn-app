# Test_app

A Turn.io Lua app - update this description to explain what your app does.

> **Note**: This file is displayed in the Turn.io UI when users view your app. Edit this file directly to customize the title and description.

## Configuration

Configure your app settings in the Turn.io UI.

## Webhook URL

Your app's webhook endpoint will be available at:

```
https://whatsapp.turn.io/apps/{app_uuid}/webhook
```

Replace `{app_uuid}` with your actual app UUID from the Turn.io UI.

You can handle incoming HTTP requests in your app's `on_event` function when `event == "http_request"`.

## Journey Functions

### hello()

Returns a greeting message.

**Usage in Journey:**
```elixir
card Greeting do
  result = app("test_app", "hello", [])
  text("@result.message")
end
```

## Development

See the main README.md for development instructions.
