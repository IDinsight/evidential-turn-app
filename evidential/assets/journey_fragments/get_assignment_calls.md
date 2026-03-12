```stack
card GetAssignmentApp, "Get Assignment App",
  version: "1",
  uuid: "3fbb9478-641e-4339-84cf-d08aebd29d08",
  code_generator: "APP" do
  ref_App_1 =
    app("evidential", "get_assignment_for_contact", [
      "@contact.whatsapp_id",
      "{{EXPERIMENT_ID}}"
    ])

  then(UpdateProfile when ref_App_1.success == true)
  then(ErrorMessage when ref_App_1.success == false)
end

```


```stack
card UpdateProfile, "Update Profile",
  version: "1",
  uuid: "38e3ae20-ce9d-4ecd-9d61-9199505dac6e",
  code_generator: "UPDATE_CONTACT" do
  update_contact(assignment_arm_id: "@ref_App_1.result.assignment")
  update_contact(experiment_id: "{{EXPERIMENT_ID}}")
  then(BranchBasedOnArms)
end

```


```stack
card ErrorMessage, "Error Message",
  version: "1",
  uuid: "0cfdda33-ab62-47d2-b362-550127de9984",
  code_generator: "TEXT_MESSAGE" do
  text("🛑  Oh no! Looks like something went wrong, we'll have to take you out of the experiment!")
end

```