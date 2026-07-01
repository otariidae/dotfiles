-- Prefer A2DP playback profiles over HFP on Bluetooth cards.
table.insert(device_defaults.profile_priorities, {
  matches = {
    {
      { "device.name", "matches", "bluez_card.*" },
    },
  },
  priorities = {
    "a2dp-sink-sbc_xq",
    "a2dp-sink-sbc",
    "a2dp-sink",
    "headset-head-unit-msbc",
    "headset-head-unit",
  },
})
