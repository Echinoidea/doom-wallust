# Wallust client for Doom Emacs
Wallust is a Pywal-like program by explosion-mental https://codeberg.org/explosion-mental/wallust

This package is essentially a client for the ~wallust theme~ command. ~M-x: doom-wallust-select-theme~ will open a window to browse the theme options (including random) where you can select it and it will run wallust, apply all wallust templates (including the theme templates included in this repository), and then reload the doom-wallust-[light|dark]-theme automatically.


# Screenshots
![image](https://github.com/Echinoidea/doom-wallust/blob/master/screenshots/wallust-1.png)
![image](https://github.com/Echinoidea/doom-wallust/blob/master/screenshots/wallust-2.png)

# Installation
Add the following to your $DOOM_DIR/packages.el
```
(package! doom-wallust
  :recipe (:local-repo "~/code/elisp/doom-wallust"
           :files ("*.el")))
```

Make sure to copy the doom-wallust-dark-theme.el and doom-wallust-light-theme.el files to your ~.config/wallust/templates/ directory AND your $DOOM_DIR/themes/ directory. Wallust requires the target file to be present in order to overwrite it.

If this package doesn't autogenerate the lines in the wallust.toml to load the template files, add the following to your wallust.toml under the [templates] section:
```
doom-wallust-light = { template = 'doom-wallust-light-theme.el', target = '/home/gabriel/.config/doom/themes/doom-wallust-light-theme.el' }
doom-wallust-dark = { template = 'doom-wallust-dark-theme.el', target = '/home/gabriel/.config/doom/themes/doom-wallust-dark-theme.el' }
```
