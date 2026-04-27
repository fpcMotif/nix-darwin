{
  bun,
  nodejs_24,
  writeShellScriptBin,
}:

writeShellScriptBin "pi-npm-bun" ''
  set -euo pipefail

  bun=${bun}/bin/bun
  npm=${nodejs_24}/bin/npm
  bun_install="''${BUN_INSTALL:-$HOME/.bun}"

  case "''${1:-}" in
    root)
      if [ "''${2:-}" = "-g" ] || [ "''${2:-}" = "--global" ]; then
        printf '%s\n' "$bun_install/install/global/node_modules"
        exit 0
      fi
      ;;
    bin)
      if [ "''${2:-}" = "-g" ] || [ "''${2:-}" = "--global" ]; then
        exec "$bun" pm bin -g
      fi
      ;;
    install|i)
      shift
      if [ "''${1:-}" = "-g" ] || [ "''${1:-}" = "--global" ]; then
        shift
        exec "$bun" add -g "$@"
      fi
      exec "$bun" install "$@"
      ;;
    uninstall|remove|rm)
      shift
      if [ "''${1:-}" = "-g" ] || [ "''${1:-}" = "--global" ]; then
        shift
      fi
      exec "$bun" remove "$@"
      ;;
    update|upgrade)
      shift
      if [ "''${1:-}" = "-g" ] || [ "''${1:-}" = "--global" ]; then
        shift
        exec "$bun" update -g "$@"
      fi
      exec "$bun" update "$@"
      ;;
    view|info)
      shift
      exec "$bun" pm view "$@"
      ;;
    --version|-v)
      exec "$bun" --version
      ;;
  esac

  exec "$npm" "$@"
''
