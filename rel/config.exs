use Mix.Releases.Config,
  default_release: :yahtzeebot,
  default_environment: Mix.env()

environment :dev do
  # If you are running Phoenix, you should make sure that
  # server: true is set and the code reloader is disabled,
  # even in dev mode.

  # It is recommended that you build with MIX_ENV=prod and pass
  # the --env flag to Distillery explicitly if you want to use
  # dev mode.

  set(dev_mode: true)
  set(include_erts: false)
  set(cookie: :"7Ev5=JTdmDxp?7X&as,82Dv6xAG:}~|<0g7[*y_(rZu^St[.jPX%7KZ1UQvWR}:b")
end

environment :prod do
  set(include_erts: true)
  set(include_src: false)
  set(cookie: :"Mjp@P@dDIH^jPw{)L[B4E<:g*U@Ycl%2.G$KwAm6BuM_Ft}3q44DP4Ra[77xFC7w")

  set(output_dir: "releases")

  # set(pre_start_hooks: "rel/hooks/pre_start")
  # set(vm_args: "rel/etc/vm.args")
  set(
    overlays: [
      {:copy, "rel/etc/yahtzeebot.service", "etc/yahtzeebot.service"},
      {:copy, "rel/etc/config.exs", "etc/config.exs"},
      {:copy, "dirty-hack/tdlib-json-cli", "priv/tdlib-json-cli"},
      {:copy, "bin/remsh", "bin/remsh"}
      # {:link, "rel/etc/yahtzeebot.service", "/etc/systemd/system/yahtzeebot.service"}
    ]
  )

  set(
    config_providers: [
      {Mix.Releases.Config.Providers.Elixir, ["${RELEASE_ROOT_DIR}/etc/config.exs"]}
    ]
  )
end

release :yahtzeebot do
  set(version: "0.1.0")

  set(
    applications: [
      :runtime_tools,
      :sasl,
      _storage: :permanent,
      core: :permanent,
      tgbot: :permanent,
      ubot: :permanent,
      web: :permanent
    ]
  )
end
