card SayHello do
  message = app("test_app", "hello")
  text("@(message.result.message)")
end