# Evidential Turn.io App

An app to integrate with the [Evidential experiments platform](https://app.evidential.dev/) and run A/B experiments on Turn.io.

## Configuration

The app requires the following configuration parameters (set in Turn.io UI):
- `Evidential API Base URL`: Base URL for Evidential API (e.g. `https://api.evidential.dev/v1/experiments`)
- `Evidential API Key`: API key for authenticating with Evidential API
- `Evidential Organization ID`: Organization ID for your Evidential account
- `Evidential Experiment Config`: JSON string with experiment details:

```json
{
  "experiment_name": "My Experiment",
  "experiment_id": "exp_12345",
  "arms": {
    "arm_id_1": "journey-uuid-for-arm-1",
    "arm_id_2": "journey-uuid-for-arm-2"
  }
}
```

The `arms` map links each Evidential arm ID to the UUID of the Turn journey that should be started for contacts assigned to that arm. Create the arm journeys first, then reference their UUIDs here.

## Journey Functions

### route_to_experiment(contact_id)

Used by the installed journey. Handles the full routing flow:
1. Calls Evidential API to get the contact's arm assignment
2. Resolves the arm ID to a journey UUID from config
3. Updates the contact's profile fields (`assignment_arm_id`, `experiment_id`)
4. Starts the arm journey via `turn.journeys.start()`

This function is called automatically by the installed Evidential Experiment journey.

### get_assignment_for_contact(contact_id)

Returns the contact's arm assignment without routing. For custom journeys that want to handle routing themselves.

**Returns on success:** `{assignment = "arm_id", experiment_id = "exp_id", journey_uuid = "uuid"}`

**Usage in Journey:**
```
app("evidential", "get_assignment_for_contact", ["@contact.whatsapp_id"])
```

### post_outcome_for_contact(contact_id, outcome)

Posts the outcome for a contact's experiment assignment back to Evidential.

**Usage in Journey:**
```
app("evidential", "post_outcome_for_contact", ["@contact.whatsapp_id", "@outcome_value"])
```

## Arm Journey Contract

Arm journeys are authored by the experiment operator and are self-contained. Each arm journey should:

1. Deliver the arm's content/intervention
2. Collect the outcome (e.g., a rating or response)
3. Call `post_outcome_for_contact` to record the outcome in Evidential

## Breaking Changes in 0.2.0

- `get_assignment_for_contact` now takes 1 argument (was 2). Experiment ID is read from config.
- `post_outcome_for_contact` now takes 2 arguments (was 3). Experiment ID is read from config.
- The installed journey has changed. The old template with hardcoded arm IDs is replaced by a generic journey that delegates routing to the app.

## Development

See the main README.md for development instructions.
