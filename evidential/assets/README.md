# Evidential Turn.io App

An app to integrate with the [Evidential experiments platform](https://app.evidential.dev/) and run experiments on Turn.io.


## Quickstart
1. Create an experiment on the [Evidential experiments platform](https://app.evidential.dev/) and note down the organization ID, API key, experiment ID and arm IDs for this experiment from the integration guide.
2. Create a new Turn.io app and add the `evidential` app as a dependency.
3. Configure the app with the required parameters (see [Configuration](#configuration) section).
4. Create a base Journey to onboard contacts for your experiment, and add a block calling the `route_to_experiment` function from the App (see [Journey Functions](#journey-functions) section).
5. Create separate Journeys for each arm of the experiment, following the [Arm Journey Contract](#arm-journey-contract), and update the corresponding arm IDs to journey UUIDs in the app config.
5. If you're running a bandit experiment and want to collect outcomes in the arm journeys, make sure to call the `post_outcome_for_contact` function from the App with the appropriate outcome value to record the outcome in Evidential for analysis. (See [Journey Functions](#journey-functions) section for details on how to use this function in your journey.)
6. Publish the app and the journeys, and start onboarding contacts to see them routed to their assigned arm journeys based on the experiment configuration in Evidential.


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

The `arms` map links each arm ID in the experiment to the UUID of the Turn journey that should be started for contacts assigned to that arm. Create the arm journeys first, then reference their UUIDs here (see [Arm Journey Contract](#arm-journey-contract) for more details).

## Journey Functions

### route_to_experiment(contact_id)

Used by the installed journey. Handles the full routing flow:
1. Calls Evidential API to get the contact's arm assignment
2. Resolves the arm ID to a journey UUID from config
3. Updates the contact's profile fields (`assignment_arm_id`, `experiment_id`)
4. Starts the arm journey via `turn.journeys.start()`

This function is called automatically by the installed Evidential Experiment journey.

**Usage in Journey:**
```
app("evidential", "route_to_experiment", ["@contact.whatsapp_id"])
```


### get_assignment_for_contact(contact_id, update_contact_fields)

Returns the contact's arm assignment without routing, and optionally updates the contact's profile fields (by default, `update_contact_fields` is `true`). For custom journeys that want to handle routing themselves.

**Returns on success:** `{assignment = "arm_id", experiment_id = "exp_id", journey_uuid = "uuid"}`

**Usage in Journey:**
```
app("evidential", "get_assignment_for_contact", ["@contact.whatsapp_id", true])
```

### post_outcome_for_contact(contact_id, outcome)

Posts the outcome for a contact's experiment assignment back to Evidential. This is only relevant for bandit experiments where the outcome is collected in the arm journey and needs to be sent back to Evidential for analysis.
Otherwise, the outcome is accessed via a separate ETL/database integration with Evidential.

**Usage in Journey:**
```
app("evidential", "post_outcome_for_contact", ["@contact.whatsapp_id", "@outcome_value"])
```

## Arm Journey Contract

Arm journeys are authored by the experiment operator and are self-contained. Each arm journey should:

1. Deliver the arm's content/intervention
2. Collect the outcome (e.g., a rating or response)
3. Call `post_outcome_for_contact` to record the outcome in Evidential

## Development

See the main README.md for development instructions.
