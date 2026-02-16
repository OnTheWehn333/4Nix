# home-modules/

Reusable Home Manager modules. One tool per file, imported by host `home.nix` files.

## Module Types

| Pattern | Files | Example |
|---------|-------|---------|
| Simple package | `portal.nix`, `claude-code.nix`, `agenix.nix`, `chafa.nix` | `home.packages = with pkgs; [ tool ];` |
| Program config | `tmux.nix`, `nushell.nix`, `ghostty.nix`, `gpg.nix` | `programs.X.enable = true; ...settings` |
| Activation script | `neovim.nix`, `rust.nix`, `opencode.nix` | `home.activation.X = lib.hm.dag.entryAfter ["writeBoundary"] ''...''` |
| Custom build | `tunnel9.nix`, `keysync.nix` | `pkgs.buildGoModule { ... }` in `let` block |
| Custom options | `opencode.nix` | `options.custom.opencode.useLatest = lib.mkEnableOption ...` |
| Script wrapper | `tmux-sessionizer.nix` | `pkgs.writeShellApplication` reading from `scripts/` |

## Where to Look

| Task | File |
|------|------|
| Add simple tool | Create `{tool}.nix`, add `home.packages` |
| Bundle related tools | `bundles/dev-tools.nix` (imports git, neovim, rust) |
| Add shell script | `scripts/` dir + `writeShellApplication` in module |
| Build Go package from source | See `tunnel9.nix` (remote) or `keysync.nix` (local) |
| Custom HM option | See `opencode.nix` pattern: `options.custom.X` + `config = { ... }` |

## Conventions

- File name = tool name, kebab-case
- Signature: `{ config, lib, pkgs, ... }:` even if args unused
- `imports = [ ... ];` at top if module depends on other modules (e.g., `keysync.nix` imports `gpg.nix`)
- Use `with pkgs;` in package lists, but NOT for single-package `let` bindings

## Anti-Patterns

- **DO NOT** import host-specific logic — modules must work on both platforms
- **DO NOT** hardcode paths — use `config.home.homeDirectory` or `config.xdg.configHome`
- Platform-specific packages MUST use `lib.optionals (!pkgs.stdenv.isDarwin) [...]`

## Notes

- `wezterm.nix`: `enable = false` — disabled in favor of ghostty
- `opencode.nix`: Largest module (320 lines), handles multi-provider AI config + activation scripts
- `keysync.nix` imports `gpg.nix` — only module with an internal dependency
- `oh-my-posh.nix`: Dynamically patches built-in theme JSON with Tokyo Night colors
