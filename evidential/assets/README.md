# Evidential Turn.io App

An app to integrate with the [Evidential experiments platform](https://app.evidential.dev/) and fetch experiment assignments for contacts on Turn.io.


## Configuration

The app requires the following configuration parameters (set in Turn.io UI):
- `Evidential API Base URL`: Base URL for Evidential API (e.g. `https://api.evidential.dev/v1/experiments`)
- `Evidential API Key`: API key for authenticating with Evidential API
- `Evidential Organization ID`: Organization ID for your Evidential account
- `Evidential Experiment Config`: JSON string with experiment details, e.g. `{"experiment_name": "exp_name", "experiment_id": "exp_12345", "arms": {"arm_id_1": "journey_uuid_1", "arm_id_2": "journey_uuid_2"}}`
NB: the `Evidential Experiment Config` should include the experiment name, experiment ID, and a mapping of arm IDs to journey UUIDs (for routing contacts to different existing journeys based on their assigned arm)

## Webhook URL

Your app's webhook endpoint will be available at:

```
https://whatsapp.turn.io/apps/{app_uuid}/webhook
```

Replace `{app_uuid}` with your actual app UUID from the Turn.io UI.

You can handle incoming HTTP requests in your app's `on_event` function when `event == "http_request"`.

## Journey Functions

### get_assignment_for_contact(contact_id, experiment_id)

Makes an API call to Evidential to fetch the experiment assignment for a given contact and experiment ID.

**Usage in Journey:**
```elixir
card GetAssignment do
  result = app("evidential", "get_assignment_for_contact", [@contact.whatsapp_id, experiment_id])
  text("@result.assignment")
end
```

### post_outcome_for_contact(contact_id, experiment_id, outcome)

Posts the outcome for a contact's experiment assignment back to Evidential.

**Usage in Journey:**
```elixir
card PostOutcome do
  result = app("evidential", "post_outcome_for_contact", [@contact.whatsapp_id, experiment_id, outcome])
  text("@result.status")
end
```

## Development

See the main README.md for development instructions.
