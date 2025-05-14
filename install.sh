# Copyright (c) 2025 Bruno Marques
# 
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

# Esse script é para incluir o arquivo start.sh no alias do seu sistema

pwd=$(pwd)
alias_path="$HOME/.bash_aliases"
alias_name="start_fastapi"
alias_command="alias $alias_name='bash $pwd/start.sh'"

if [ -f "$alias_path" ]; then
    if ! grep -q "$alias_name" "$alias_path"; then
        echo "$alias_command" >> "$alias_path"
        echo "Alias '$alias_name' adicionado ao arquivo $alias_path."
    else
        echo "Alias '$alias_name' já existe no arquivo $alias_path."
    fi
else
    echo "$alias_command" > "$alias_path"
    echo "Arquivo $alias_path criado e alias '$alias_name' adicionado."
fi
