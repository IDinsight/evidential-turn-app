
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

  then(Text_3 when ref_Consent == "Yes")
  then(Baseline when ref_Consent == "No")
end

```


```stack
card Baseline, "Baseline",
  version: "1",
  uuid: "bb452839-17b8-4e1b-9340-f446d3aff295",
  code_generator: "TEXT_MESSAGE" do
  text("👌🏾 No problem!  We'll take you out of the experiment.")
  then(Text_4)
end

```


```stack
card Branch_1, "Branch_1",
  version: "1",
  uuid: "15752643-5c7f-4e4d-a55f-d716d7fead4a",
  code_generator: "CONDITIONALS" do
  then(Text_5 when has_phrase(@contact.assignment_arm_id, arm_wqQXq8DiMUy7Xzyg))
  then(Text_6 when has_phrase(@contact.assignment_arm_id, arm_gIMiLvDRFaP8296w))
  then(Text_7 when has_phrase(@contact.assignment_arm_id, arm_LBJV9ej7j5mjpjR5))
  then(Text_2)
end

```


```stack
card Text_1, "Text_1",
  version: "1",
  uuid: "976047e4-ce37-4e66-8d2f-42cee1e575cf",
  code_generator: "TEXT_MESSAGE" do
  text(
    "🤗  Thanks for your response -- we've recorded it, and it will help us figure out how to improve our wellness messaging."
  )

  then(Text_4)
end

```


```stack
card Text_2, "Text_2",
  version: "1",
  uuid: "0cfdda33-ab62-47d2-b362-550127de9984",
  code_generator: "TEXT_MESSAGE" do
  text("🛑  Oh no! Looks like something went wrong, we'll have to take you out of the experiment!")
end

```


```stack
card Buttons_1, "Buttons_1",
  version: "1",
  uuid: "2b551171-c16b-4d8e-9eb1-eecabab1f264",
  code_generator: "REPLY_BUTTON_TEXT" do
  outcome_label =
    buttons(Insight: "Yes, I did all three", Insight: "No, not all 3") do
      text("Did you actually do all three things to correct your posture just now?

 (be honest, no judgement!)
")
    end
end

```


```stack
card Text_3, "Text_3",
  version: "1",
  uuid: "ff19bdfc-4e39-4c69-b298-e106ce1adb02",
  code_generator: "TEXT_MESSAGE" do
  text("Great! Let's go 🏃🏽‍♀️")
  then(App_1)
end

```


```stack
card Text_4, "Text_4",
  version: "1",
  uuid: "6bab2aca-c07a-496a-b95a-17e1a0f33c04",
  code_generator: "TEXT_MESSAGE" do
  text("👋  Goodbye, and thanks for participating! 

🌻  We hope you'll consider creating similar experiments for your tool the future!

👀  In the meantime, you can learn more about Evidential here:  https://docs.evidential.dev/ 
")
end

```
  
```stack
card Text_5, "Text_5",
  version: "1",
  uuid: "01bb1873-7c8f-41b5-b257-4b9bec0386d0",
  code_generator: "TEXT_MESSAGE" do
  text("❔ Did you know?


👩🏾‍💼 Poor posture causes 60% of chronic neck pain in office workers. 


🚶🏾‍♀️‍➡️ Roll your neck, pull shoulders back, and ensure feet are flat on the floor.

")
  then(Buttons_1)
end

```


```stack
card Text_6, "Text_6",
  version: "1",
  uuid: "ca632de8-d4bb-41f0-8938-96ec9e487e72",
  code_generator: "TEXT_MESSAGE" do
  text(
    "👀 Caught you slouching! 


❕ Quick posture check: roll your neck, pull those shoulders back and put your feet flat on the floor!

👩🏾‍💼 And remember to keep doing this during office hours -- otherwise you might end up with chronic neck pain! "
  )

  then(Buttons_1)
end

```


```stack
card Text_7, "Text_7",
  version: "1",
  uuid: "64a5130f-770e-45ae-a46f-42673c2c8126",
  code_generator: "TEXT_MESSAGE" do
  text("🤺 Posture challenge! 


Do this right now: 
1) Shoulders back ✅
2) Roll your neck ✅
3) Feet flat on floor ✅


Done all three?  You nailed it 🍾🎊🥳


👩🏾‍💼 Remember to keep doing this during office hours -- otherwise you might end up with chronic neck pain! 
")
  then(Buttons_1)
end

```


```stack
card Insight, "Insight",
  version: "1",
  uuid: "60358f9f-eaab-4b67-9201-435c46d3c3b3",
  code_generator: "WRITE_RESULTS" do
  outcome =
    if @outcome_label.label == "Yes, I did all three" do
      "1"
    else
      "0"
    end

  write_result("outcome", "")
  then(App_2)
end

```


```stack
card App_1, "App_1",
  version: "1",
  uuid: "3fbb9478-641e-4339-84cf-d08aebd29d08",
  code_generator: "APP" do
  ref_App_1 =
    app("evidential", "get_assignment_for_contact", [
      "@contact.whatsapp_id",
      "exp_0aFAD1bF9kpUsRsE"
    ])

  then(Profile_1 when ref_App_1.success == true)
  then(Text_2 when ref_App_1.success == false)
end

```


```stack
card Profile_1, "Profile_1",
  version: "1",
  uuid: "38e3ae20-ce9d-4ecd-9d61-9199505dac6e",
  code_generator: "UPDATE_CONTACT" do
  update_contact(assignment_arm_id: "@ref_App_1.result.assignment")
  then(Branch_1)
end

```


```stack
card App_2, "App_2",
  version: "1",
  uuid: "c8196fdc-27eb-4957-8d44-20a2f813d5f5",
  code_generator: "APP" do
  ref_App_2 =
    app("evidential", "post_outcome_for_contact", [
      "@contact.whatsapp_id",
      "exp_0aFAD1bF9kpUsRsE",
      "@outcome"
    ])

  then(Text_1 when ref_App_2.success == true)
  then(Text_2 when ref_App_2.success == false)
end

```


```stack
card RESERVED_DEFAULT_CARD, "RESERVED_DEFAULT_CARD", code_generator: "RESERVED_DEFAULT_CARD" do
  # RESERVED_DEFAULT_CARD
end

```


```stack
interaction_timeout(300)

```