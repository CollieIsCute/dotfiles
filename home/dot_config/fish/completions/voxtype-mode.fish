complete -c voxtype-mode -f
complete -c voxtype-mode -s h -l help -d 'Show help'
complete -c voxtype-mode -n 'not __fish_seen_subcommand_from whisper-turbo whisper-large sensevoice qwen-1.7b off' -a whisper-turbo -d 'Whisper large-v3-turbo (Vulkan)'
complete -c voxtype-mode -n 'not __fish_seen_subcommand_from whisper-turbo whisper-large sensevoice qwen-1.7b off' -a whisper-large -d 'Whisper large-v3 (Vulkan)'
complete -c voxtype-mode -n 'not __fish_seen_subcommand_from whisper-turbo whisper-large sensevoice qwen-1.7b off' -a sensevoice -d 'SenseVoiceSmall FP32 (CPU)'
complete -c voxtype-mode -n 'not __fish_seen_subcommand_from whisper-turbo whisper-large sensevoice qwen-1.7b off' -a qwen-1.7b -d 'Qwen3-ASR 1.7B Q8_0 (Vulkan)'
complete -c voxtype-mode -n 'not __fish_seen_subcommand_from whisper-turbo whisper-large sensevoice qwen-1.7b off' -a off -d 'Stop all managed ASR processes'
