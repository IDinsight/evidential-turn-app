<!-- { section: "", x: -216, y: 288} -->

```stack
trigger(on: "MESSAGE RECEIVED") when has_only_phrase(event.message.text.body, "evidential--arm-1")

```

<!-- { section: "", x: 120, y: 288} -->

```stack
card Arm_1, "Arm_1",
  version: "1",
  uuid: "01bb1873-7c8f-41b5-b257-4b9bec0386d0",
  code_generator: "TEXT_MESSAGE" do
  text("❔ Did you know?


👩🏾‍💼 Poor posture causes 60% of chronic neck pain in office workers. 


🚶🏾‍♀️‍➡️ Roll your neck, pull shoulders back, and ensure feet are flat on the floor.

")
  then(PresentOptions)
end

```

<!-- { section: "", x: 456, y: 288} -->

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

<!-- { section: "", x: 816, y: 432} -->

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

<!-- { section: "", x: 432, y: 720} -->

```stack
card SendResultsToApp, "SendResultsToApp",
  version: "1",
  uuid: "c8196fdc-27eb-4957-8d44-20a2f813d5f5",
  code_generator: "APP" do
  app("evidential", "post_outcome_for_contact", ["@contact.whatsapp_id", "@outcome"])
  then(ThankYouMessage)
end

```

<!-- { section: "", x: 768, y: 720} -->

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

<!-- { section: "", x: 1128, y: 720} -->

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
