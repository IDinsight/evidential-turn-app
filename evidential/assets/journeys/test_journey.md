<!-- { section: "4d06b241-debf-408d-b1a9-bec04b4f884f", x: 456, y: 0} -->

```stack
card App_1, "App_1",
  version: "1",
  uuid: "1fc1b00d-eeb1-4634-ad3e-835293f49002",
  code_generator: "APP" do
  ref_App_1 = app("evidential", "hello", ["@contact.name"])
  then(Text_1 when ref_App_1.success == true)
  then(RESERVED_DEFAULT_CARD when ref_App_1.success == false)
end

```

<!-- { section: "22a4fe48-1458-4f3d-94da-af564fa24e11", x: 888, y: 192} -->

```stack
card Text_1, "Text_1",
  version: "1",
  uuid: "d564c441-d80e-4716-8b5d-25e8735e32d4",
  code_generator: "TEXT_MESSAGE" do
  text("@ref_App_1.result.message")
end

```

<!-- { section: "6ae0ba65-1fcf-435b-b991-555e3c01213a", x: 0, y: 0} -->

```stack
card RESERVED_TRIGGER, "RESERVED_TRIGGER", code_generator: "RESERVED_TRIGGER" do
  # placeholder_trigger
end

```

<!-- { section: "3de0acc8-45c5-48d8-82b0-8680b679eb79", x: -1000, y: 0} -->

```stack
card RESERVED_DEFAULT_CARD, "RESERVED_DEFAULT_CARD", code_generator: "RESERVED_DEFAULT_CARD" do
  # RESERVED_DEFAULT_CARD
end

```

<!-- { section: "INTERACTION_TIMEOUT_CELL", x: 0, y: 0} -->

```stack
interaction_timeout(300)

```
