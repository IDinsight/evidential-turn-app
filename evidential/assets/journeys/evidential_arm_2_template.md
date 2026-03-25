```stack
trigger(on: "MESSAGE RECEIVED") when has_only_phrase(event.message.text.body, "evidential-test")

```


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
end

```