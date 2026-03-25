```stack
trigger(on: "MESSAGE RECEIVED") when has_only_phrase(event.message.text.body, "evidential-test")

```


```stack
card Arm_1, "Arm_1",
  version: "1",
  uuid: "01bb1873-7c8f-41b5-b257-4b9bec0386d0",
  code_generator: "TEXT_MESSAGE" do
  text("❔ Did you know?


👩🏾‍💼 Poor posture causes 60% of chronic neck pain in office workers. 


🚶🏾‍♀️‍➡️ Roll your neck, pull shoulders back, and ensure feet are flat on the floor.

")
end

```