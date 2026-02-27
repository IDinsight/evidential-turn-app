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


```stack
card Text_1, "Text_1",
  version: "1",
  uuid: "d564c441-d80e-4716-8b5d-25e8735e32d4",
  code_generator: "TEXT_MESSAGE" do
  text("@ref_App_1.result.message")
  then(App_2)
end

```


```stack
card App_2, "App_2",
  version: "1",
  uuid: "8bb5fd7d-2b5f-4b10-ad9d-c2135edd0db3",
  code_generator: "APP" do
  ref_App_2 =
    app("evidential", "get_assignment_for_contact", ["Juston", "exp_0aFAD1bF9kpUsRsE"])

  log(nil)
  then(Text_2 when ref_App_2.success == true)
  then(Text_3 when ref_App_2.success == false)
end

```

```stack
card Text_2, "Text_2",
  version: "1",
  uuid: "546ba046-ab37-49a1-87c4-ce2cdeb4eef8",
  code_generator: "TEXT_MESSAGE" do
  text("success

@ref_App_2.result.assignment")
end

```

```stack
card Text_3, "Text_3",
  version: "1",
  uuid: "d2456dfc-3465-49c1-8267-8ec6c89bb54d",
  code_generator: "TEXT_MESSAGE" do
  text("failed")
end

```

```stack
card RESERVED_TRIGGER, "RESERVED_TRIGGER", code_generator: "RESERVED_TRIGGER" do
  # placeholder_trigger
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