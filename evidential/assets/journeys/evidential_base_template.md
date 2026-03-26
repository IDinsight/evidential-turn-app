```stack
trigger(on: "MESSAGE RECEIVED") when has_only_phrase(event.message.text.body, "evidential-test")

```


```stack
card Greeting, "Greeting",
  version: "1",
  uuid: "dc24ea0d-8f6e-514c-aaf9-c1a4d79c9898",
  code_generator: "TEXT_MESSAGE" do
  text("Hi, welcome to Evidential 🦝


💊 You're about to receive a workplace wellness tip and help us test different messaging approaches in real-time.


Here's what to do:
➡️ You'll get a health/wellness message shortly.

👍🏾/ 👎🏾 Rate how useful it is with the emoji options provided

📊 Your responses will appear live on our demo dashboard!")
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
      text("🙅🏽‍♀️ We are NOT collecting any other information, EXCEPT your usefulness rating.

Do you consent to participate in the experiment?")
    end

  then(GoToExperiment when ref_Consent == "Yes")
  then(OptOut when ref_Consent == "No")
end

```


```stack
card GoToExperiment, "GoToExperiment",
  version: "1",
  uuid: "ff19bdfc-4e39-4c69-b298-e106ce1adb02",
  code_generator: "TEXT_MESSAGE" do
  text("Great! Let's go 🏃🏽‍♀️")
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
  then(PresentOptions when ref_RouteToExperiment.success == true)
end

```


```stack
card ErrorMessage, "ErrorMessage",
  version: "1",
  uuid: "0cfdda33-ab62-47d2-b362-550127de9984",
  code_generator: "TEXT_MESSAGE" do
  text("🛑  Sorry, something went wrong setting up your experiment. Please try again later!")
end

```


```stack
card OptOut, "OptOut",
  version: "1",
  uuid: "bb452839-17b8-4e1b-9340-f446d3aff295",
  code_generator: "TEXT_MESSAGE" do
  text("👌🏾 No problem!  We'll take you out of the experiment.")
end

```


```stack
interaction_timeout(300)

```