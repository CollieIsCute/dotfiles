# ~/.config/fish/functions/manp.fish
# manp: Display a manual page for a selected command using fzf.
# If 'man' fails to find the manual, fallback to tldr (if installed).

function manp --description 'Browse and view man pages with fzf'
    argparse r/refresh -- $argv
    or return 1

    command -q fzf
    or begin
        echo "manp: fzf is required" >&2
        return 1
    end

    # 快取檔案路徑（依 PATH hash）
    set -l cache_file /tmp/fish_manp_cmds_(string md5 -- "$PATH")

    # 若有 --refresh/-r 參數則強制重建快取
    test -n "$_flag_refresh" && rm -f $cache_file

    # 若快取不存在則重建
    if not test -f $cache_file
        for dir in $PATH
            test -d $dir || continue
            for cmd in $dir/*
                test -x $cmd && basename $cmd
            end
        end | sort -u >$cache_file
    end

    set -l cmd (fzf --cycle <$cache_file)
    test -n "$cmd" || return

    man $cmd 2>/dev/null
    or command -q tldr && tldr $cmd
end
