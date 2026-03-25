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
card PresentOptions, "PresentOptions",
  version: "1",
  uuid: "2b551171-c16b-4d8e-9eb1-eecabab1f264",
  code_generator: "REPLY_BUTTON_TEXT" do
  outcome_label =
    buttons(RecordOutcome: "Yes, I did all three", RecordOutcome: "No, not all 3") do
      text("Did you actually do all three things to correct your posture just now?
 (be honest, no judgement!)
")
    end
end

```


```stack
card RecordOutcome, "RecordOutcome",
  version: "1",
  uuid: "60358f9f-eaab-4b67-9201-435c46d3c3b3",
  code_generator: "WRITE_RESULTS" do
  outcome =
    if @outcome_label.label == "Yes, I did all three" do
      "1"
    else
      "0"
    end

  write_result("outcome", outcome)
  then(SendResultsToApp)
end

```


```stack
card SendResultsToApp, "SendResultsToApp",
  version: "1",
  uuid: "c8196fdc-27eb-4957-8d44-20a2f813d5f5",
  code_generator: "APP" do
  app("evidential", "post_outcome_for_contact", [
    "@contact.whatsapp_id",
    "exp_0aFAD1bF9kpUsRsE",
    "@outcome"
  ])

  then(ThankYouMessage)
end

```

```stack
card ThankYouMessage, "ThankYouMessage",
  version: "1",
  uuid: "976047e4-ce37-4e66-8d2f-42cee1e575cf",
  code_generator: "TEXT_MESSAGE" do
  text(
    "🤗  Thanks for your response -- we've recorded it, and it will help us figure out how to improve our wellness messaging."
  )

  then(GoodbyeMessage)
end

```

```stack
card GoodbyeMessage, "GoodbyeMessage",
  version: "1",
  uuid: "6bab2aca-c07a-496a-b95a-17e1a0f33c04",
  code_generator: "TEXT_MESSAGE" do
  text("👋  Goodbye, and thanks for participating!

🌻  We hope you'll consider creating similar experiments for your tool the future!

👀  In the meantime, you can learn more about Evidential here:  https://docs.evidential.dev/ \
")
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