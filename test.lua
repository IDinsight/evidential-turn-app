print("Hello world")
require("test_app.test_app")

config_table = turn.app.get_config()
print("Config table", config_table)

config_table["a"] = 10;
for k, v in pairs(config_table) do
  print(k, v)
end
