```stack
trigger(on: "MESSAGE RECEIVED") when has_only_phrase(event.message.text.body, "evidential-test")

```


```stack
card Arm_3, "Arm_3",
  version: "1",
  uuid: "01bb1873-7c8f-41b5-b257-4b9bec0386d0",
  code_generator: "TEXT_MESSAGE" do
  text("🤺 Posture challenge! 


Do this right now: 
1) Shoulders back ✅
2) Roll your neck ✅
3) Feet flat on floor ✅


Done all three?  You nailed it 🍾🎊🥳


👩🏾‍💼 Remember to keep doing this during office hours -- otherwise you might end up with chronic neck pain! 
"
)
end

```