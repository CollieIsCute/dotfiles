function zz --description 'Previous dir (zoxide if available)' --wraps prevd
    if functions -q z
        z -
    else
        prevd
    end
end
