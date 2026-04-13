<!-- { section: "", x: -504, y: 312} -->

```stack
trigger(on: "MESSAGE RECEIVED") when has_only_phrase(event.message.text.body, "evidential-arm-2")

```

<!-- { section: "", x: -168, y: 312} -->

```stack
card Arm_2, "Arm_2",
  version: "1",
  uuid: "01bb1873-7c8f-41b5-b257-4b9bec0386d0",
  code_generator: "TEXT_MESSAGE" do
  text(
    "👀 Caught you slouching! 


❕ Quick posture check: roll your neck, pull those shoulders back and put your feet flat on the floor!

👩🏾‍💼 And remember to keep doing this during office hours -- otherwise you might end up with chronic neck pain! "
  )

  then(PresentOptions)
end

```

<!-- { section: "", x: 192, y: 312} -->

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

<!-- { section: "", x: 552, y: 336} -->

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

<!-- { section: "", x: 888, y: 336} -->

```stack
card SendResultsToApp, "SendResultsToApp",
  version: "1",
  uuid: "c8196fdc-27eb-4957-8d44-20a2f813d5f5",
  code_generator: "APP" do
  ref_SendResultsToApp =
    app("evidential", "post_outcome_for_contact", ["@contact.whatsapp_id", "@outcome"])

  then(ThankYouMessage)
end

```

<!-- { section: "", x: 1224, y: 336} -->

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

<!-- { section: "", x: 1560, y: 336} -->

```stack
card GoodbyeMessage, "GoodbyeMessage",
  version: "1",
  uuid: "6bab2aca-c07a-496a-b95a-17e1a0f33c04",
  code_generator: "TEXT_MESSAGE" do
  text("👋  Goodbye, and thanks for participating!

🌻  We hope you'll consider creating similar experiments for your tool the future!

👀  In the meantime, you can learn more about Evidential here:  https://docs.evidential.dev/
")
end

```
