# Dotfiles

adevore3's dotfiles

Includes:
* Vim settings
* Tmux settings
* Autojump
* Cheat
* Work specific configs are set up in a private work repository and added as a git submodule

## Notes

This repo contains submodules and an easy way to clone those along with this repo is using the following command

Old way that doesn't seem to work anymore
```
git clone --recurse-submodules git@github.com:adevore3/dotfiles.git

```

New way requires `gh` package. clone command doesn't have an option for submodules
```
gh repo clone adevore3/dotfiles
git submodule update --init --recursive
```

If submodules don't initialize properly
```
git submodule update --init --force --remote
```

## Inspiration

This was inspired by anishathalye's [article][managing_your_dotfiles] on how
to manage your own dotfiles using his [dotfiles template][anishathalye_dotfiles_templates]
and [dotbot][dotbot].

## License

This software is hereby released into the public domain. That means you can do
whatever you want with it without restriction. See `LICENSE.md` for details.

That being said, I would appreciate it if you could maintain a link back to
Dotbot (or this repository) to help other people discover Dotbot.

[dotbot]: https://github.com/anishathalye/dotbot
[anishathalye_dotfiles_templates]: https://github.com/anishathalye/dotfiles_template
[managing_your_dotfiles]: http://www.anishathalye.com/2014/08/03/managing-your-dotfiles/

