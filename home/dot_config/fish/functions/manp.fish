# ~/.config/fish/functions/manp.fish
# manp: Display a manual page for a selected command using fzf.
# If 'man' fails to find the manual, fallback to tldr (if installed).

function manp
    # Check for dependencies before proceeding
    if not type -q fzf
        echo "fzf is not installed. Please install fzf to use this function."
        return 1
    end

    set -l has_tldr 1
    if not type -q tldr
        set has_tldr 0
        echo "tldr is not installed. Fallback to tldr will not be available."
    end

    # 快取檔案路徑（依 PATH hash）
    set -l path_hash (string md5 -- $PATH)
    set -l cache_file "/tmp/fish_manp_cmds_$path_hash"

    # 若有 --refresh 參數則強制重建快取
    if test (count $argv) -ge 1; and test $argv[1] = '--refresh'
        rm -f $cache_file
    end

    # 若快取不存在則重建
    if not test -f $cache_file
        for dir in (string split \n $PATH)
            if test -d $dir
                for cmd in $dir/*
                    if test -x $cmd
                        echo (basename $cmd)
                    end
                end
            end
        end | sort -u > $cache_file
    end

    cat $cache_file | fzf --cycle | read -l cmd

    if test -n "$cmd"
        man $cmd 2>/dev/null
        if test $status -ne 0
            if test $has_tldr -eq 1
                tldr $cmd
            end
        end
    end
end
