
```stack
trigger(on: "MESSAGE RECEIVED") when has_only_phrase(event.message.text.body, "evidential-test")

```


```stack
card Greeting, "Greeting",
  version: "1",
  uuid: "dc24ea0d-8f6e-514c-aaf9-c1a4d79c9898",
  code_generator: "TEXT_MESSAGE" do
  text("Welcome to the Evidential experiment.

You are about to participate in an experiment. We'll assign you to a group and guide you through the experience.")
  then(Consent)
end

```


```stack
card Consent, "Consent",
  version: "1",
  uuid: "b61e9b30-ef30-4af8-9433-b394a9bcd79c",
  code_generator: "REPLY_BUTTON_TEXT" do
  ref_Consent =
    buttons(["Yes", "No"]) do
      text("Do you consent to participate in this experiment?")
    end

  then(GoToExperiment when ref_Consent == "Yes")
  then(OptOut when ref_Consent == "No")
end

```


```stack
card OptOut, "OptOut",
  version: "1",
  uuid: "bb452839-17b8-4e1b-9340-f446d3aff295",
  code_generator: "TEXT_MESSAGE" do
  text("No problem! You will not participate in this experiment. Goodbye!")
end

```


```stack
card GoToExperiment, "GoToExperiment",
  version: "1",
  uuid: "ff19bdfc-4e39-4c69-b298-e106ce1adb02",
  code_generator: "TEXT_MESSAGE" do
  text("Great! Let's get started.")
  then(RouteToExperiment)
end

```


```stack
card RouteToExperiment, "RouteToExperiment",
  version: "1",
  uuid: "3fbb9478-641e-4339-84cf-d08aebd29d08",
  code_generator: "APP" do
  ref_RouteToExperiment =
    app("evidential", "route_to_experiment", [
      "@contact.whatsapp_id"
    ])

  then(ErrorMessage when ref_RouteToExperiment.success == false)
end

```


```stack
card ErrorMessage, "ErrorMessage",
  version: "1",
  uuid: "0cfdda33-ab62-47d2-b362-550127de9984",
  code_generator: "TEXT_MESSAGE" do
  text("Sorry, something went wrong setting up your experiment. Please try again later.")
end

```


```stack
interaction_timeout(300)

```
