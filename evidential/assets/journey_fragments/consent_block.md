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
  then(Baseline when ref_Consent == "No")
end

```

```stack
card Baseline, "Baseline",
  version: "1",
  uuid: "bb452839-17b8-4e1b-9340-f446d3aff295",
  code_generator: "TEXT_MESSAGE" do
  text("👌🏾 No problem!  We'll take you out of the experiment.")
end

```

```stack
card GoToExperiment, "Go To Experiment",
  version: "1",
  uuid: "ff19bdfc-4e39-4c69-b298-e106ce1adb02",
  code_generator: "TEXT_MESSAGE" do
  text("Great! Let's go 🏃🏽‍♀️")
  then(GetAssignmentApp)
end

```