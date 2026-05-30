# Zsh Config

`dotfiles/.zshrc` is the entry point. It sets `DOTFILESSRC`, sources OS detection when available, then loads `~/.config/zsh/init.zsh`.

Load order:

1. `env.zsh` for exported variables.
2. `path.zsh` for PATH construction and dedupe.
3. `options.zsh` for history and zsh options.
4. Interactive startup pushes the prompt to the bottom of the terminal when `ZSH_START_AT_BOTTOM` is not `0`.
5. `plugins.zsh` for interactive-only oh-my-zsh, prompt, history, and completion integrations.
6. `aliases.zsh` for aliases.
7. `functions.zsh` for shell functions.
8. `hosts/$HOSTNAME.zsh` for machine-specific overrides.
