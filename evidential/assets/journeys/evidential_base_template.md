<!-- { section: "ae73d38a-5a1f-4f90-bfb9-ac68462774fd", x: -264, y: 288} -->

```stack
trigger(on: "MESSAGE RECEIVED") when has_only_phrase(event.message.text.body, "evidential-test")

```

<!-- { section: "e8f717cf-b80d-4d3c-aca1-c1b6654028d8", x: 72, y: 288} -->

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

<!-- { section: "55a6af8a-dbfd-4a18-8df9-8f7b13811c2c", x: 408, y: 288} -->

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

<!-- { section: "6d6af2c1-4563-4861-9f1e-2b5f491fb59c", x: 768, y: 360} -->

```stack
card GoToExperiment, "GoToExperiment",
  version: "1",
  uuid: "ff19bdfc-4e39-4c69-b298-e106ce1adb02",
  code_generator: "TEXT_MESSAGE" do
  text("Great! Let's go 🏃🏽‍♀️")
  then(RouteToExperiment)
end

```

<!-- { section: "e5620a77-ebfe-41be-9910-31d2b726fa61", x: 1128, y: 360} -->

```stack
card RouteToExperiment, "RouteToExperiment",
  version: "1",
  uuid: "3fbb9478-641e-4339-84cf-d08aebd29d08",
  code_generator: "APP" do
  ref_RouteToExperiment = app("evidential", "route_to_experiment", ["@contact.whatsapp_id"])
  then(ErrorMessage when ref_RouteToExperiment.success == false)
end

```

<!-- { section: "8351e85c-1e38-4653-829d-687c6fee5473", x: 1152, y: 864} -->

```stack
card ErrorMessage, "ErrorMessage",
  version: "1",
  uuid: "0cfdda33-ab62-47d2-b362-550127de9984",
  code_generator: "TEXT_MESSAGE" do
  text("🛑  Sorry, something went wrong setting up your experiment. Please try again later!")
end

```

<!-- { section: "1d06326b-0125-4990-9da9-541c54d00638", x: 768, y: 624} -->

```stack
card OptOut, "OptOut",
  version: "1",
  uuid: "bb452839-17b8-4e1b-9340-f446d3aff295",
  code_generator: "TEXT_MESSAGE" do
  text("👌🏾 No problem!  We'll take you out of the experiment.")
end

```

<!-- { section: "50e49dc7-a25d-47ab-8f68-5e053ef32618", x: 504, y: 816} -->

```stack
interaction_timeout(300)

```

<!-- { section: "INTERACTION_TIMEOUT_CELL", x: 0, y: 0} -->

```stack
interaction_timeout(300)

```