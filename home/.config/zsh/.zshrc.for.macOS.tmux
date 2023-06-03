# I don't know why this command not work in .tmux.conf
which tmux > /dev/null && cut -c3- ~/.tmux.conf | sh -s _apply_configuration
