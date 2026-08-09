function voxtype-post-process --description 'Convert dictation to Taiwan Traditional Chinese with CJK spacing'
    opencc -c s2twp.json \
        | perl -CSD -pe 's/([\p{Han}])([A-Za-z0-9])/$1 $2/g; s/([A-Za-z0-9])([\p{Han}])/$1 $2/g'
    set -l statuses $pipestatus
    test $statuses[1] -eq 0 -a $statuses[2] -eq 0
end
