function zz --description 'Previous dir (z if available)'
    if type -q z
        command z -
    else
        prevd  # 等價於更智慧的 cd -
    end
end
