function bat
  {{ if eq .chezmoi.os "linux" }}
    {{if (.chezmoi.osRelease.id | lower) | contains "ubuntu" -}}
    # There is a name collision in ubuntu https://github.com/sharkdp/bat/issues/982
      command batcat --pager='never' $argv
    {{ end }}
  {{ else }}
    command bat --pager='never' $argv
  {{ end}}
end