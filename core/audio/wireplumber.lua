-- WirePlumber configuration for balena-sound
-- Simplified configuration for container environment

-- Basic configuration
config = {}
config.properties = {}
config.components = {
  {
    name = "libwireplumber-module-default-nodes-api",
    type = "module",
  },
  {
    name = "libwireplumber-module-default-profile",
    type = "module",
  },
  {
    name = "libwireplumber-module-default-routes",
    type = "module",
  },
}

-- Simple rule to prevent virtual sinks from being suspended
rule = {
  matches = {
    {
      { "node.name", "matches", "balena-sound.*" },
    },
    {
      { "node.name", "matches", "snapcast" },
    },
  },
  apply_properties = {
    ["node.pause-on-idle"] = false,
    ["session.suspend-timeout-seconds"] = 0,
  },
}

-- Set balena-sound.input as default sink
default_sink_rule = {
  matches = {
    {
      { "node.name", "equals", "balena-sound.input" },
    },
  },
  apply_properties = {
    ["node.nick"] = "balena-sound Input",
    ["priority.driver"] = 1000,
    ["priority.session"] = 1000,
  },
}

-- Function to create simple audio routing
function create_balena_sound_routing()
  -- Get environment variables
  local mode = os.getenv("SOUND_MODE") or "MULTI_ROOM"
  local input_latency = tonumber(os.getenv("SOUND_INPUT_LATENCY")) or 200
  local output_latency = tonumber(os.getenv("SOUND_OUTPUT_LATENCY")) or 200
  
  print("WirePlumber: Setting up balena-sound routing for mode: " .. mode)
  print("WirePlumber: Input latency: " .. input_latency .. "ms")
  print("WirePlumber: Output latency: " .. output_latency .. "ms")
  
  -- Simple routing based on mode
  if mode == "STANDALONE" or mode == "MULTI_ROOM_CLIENT" then
    print("WirePlumber: Routing balena-sound.input -> balena-sound.output")
  else
    print("WirePlumber: Routing balena-sound.input -> snapcast")
  end
end

-- Initialize routing
create_balena_sound_routing()

-- Export configuration
return config
