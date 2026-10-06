fzf_theme_opts="\
--color=bg+:#24283b
--color=bg:#1a1b26
--color=spinner:#c0caf5
--color=hl:#f7768e
--color=fg:#c0caf5
--color=header:#f7768e
--color=info:#7aa2f7
--color=pointer:#c0caf5
--color=marker:#9aa5ce
--color=fg+:#c0caf5
--color=prompt:#7aa2f7
--color=hl+:#f7768e
--color=selected-bg:#15161e
--color=border:#283457
--color=label:#c0caf5"

export FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS:+$FZF_DEFAULT_OPTS
}$fzf_theme_opts"
