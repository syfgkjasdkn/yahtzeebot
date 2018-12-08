use Mix.Config

config :kernel, inet_dist_use_interface: {127, 0, 0, 1}

import_config "#{Mix.env()}.exs"
