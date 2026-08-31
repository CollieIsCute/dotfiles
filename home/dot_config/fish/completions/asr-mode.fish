complete -c asr-mode -f
complete -c asr-mode -s h -l help -d 'Show help'
complete -c asr-mode -n 'not __fish_seen_subcommand_from sensevoice qwen-1.7b off' -a sensevoice -d 'SenseVoice Small Q8_0 (CPU)'
complete -c asr-mode -n 'not __fish_seen_subcommand_from sensevoice qwen-1.7b off' -a qwen-1.7b -d 'Qwen3-ASR 1.7B Q8_0 (GPU)'
complete -c asr-mode -n 'not __fish_seen_subcommand_from sensevoice qwen-1.7b off' -a off -d 'Stop CrispASR and release its resources'
