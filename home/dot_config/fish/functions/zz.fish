function zz --description 'Previous dir (zoxide if available)'
    functions -q z && z - || prevd
end
