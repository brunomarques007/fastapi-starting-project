#!/bin/bash -i

# Copyright (c) 2025 bruno.marques
# Released under the MIT License.
# https://opensource.org/licenses/MIT

set -e

function instalar_dependencias() {
  sudo apt-get update -y > /dev/null
  for cmd in python3 pip git gh figlet; do
    command -v $cmd >/dev/null || sudo apt-get install -y $cmd
  done
  command -v pipx >/dev/null || pip install pipx
  command -v poetry >/dev/null || pipx install poetry && pipx inject poetry poetry-plugin-shell
  command -v ignr >/dev/null || pipx install ignr
}

function exibir_apresentacao() {
  echo -e "\033[1;39;104m $(figlet Projeto FastAPI) \033[0m\n"
  echo -e "\033[1;93mOlá, qual é o nome do projeto? Favor usar - ao invés de _.\033[m"
}

function ler_informacoes_projeto() {
  read -p 'Nome do Projeto: ' projeto
  projeto=$(echo "$projeto" | tr '[:upper:]' '[:lower:]')

  if [[ "$projeto" == *"_"* ]]; then
    echo -e "\033[1;31mPor favor, use hífen (-) ao invés de underline (_).\033[0m"
    exit 1
  fi

  read -p 'Descrição do projeto: ' descricao
  read -p 'Autor do projeto: ' autor
  read -p 'Nome da companhia: ' companhia
  read -p 'Versão do Python (ex: 3.12): ' python_version

  name_api=$(echo "$projeto" | sed "s,-,_,g")
}

function confirmar_remocao_diretorio() {
  echo -e "\n\033[1;30;103m\u26A0 Atenção \u26A0 \033[m"
  echo -e "\033[1;39;41mCaso exista um diretório com o mesmo nome do projeto, ele será removido.\033[m"
  sleep 3
}

function criar_estrutura_projeto() {
  rm -rf "$projeto"
  poetry new --flat "$projeto"
  pushd "$projeto" > /dev/null
  poetry env use "$python_version"
}

function configurar_git() {
  read -p 'Deseja utilizar o git? [y/n]: ' isgit
  if [[ "$isgit" == "y" ]]; then
    git init
    ignr -p python > .gitignore
    gh auth login
    gh repo create --source=. --public --push
    git add .
    git commit -m "Commit inicial, estrutura do projeto"
    git push --set-upstream origin main
  fi
}

function instalar_dependencias_python() {
  poetry add --group dev ruff pytest pytest-cov pytest-blue taskipy
  poetry add --group doc mkdocs mkdocs-material mkdocstrings mkdocstrings-python

  if [[ "$isgit" == "y" ]]; then
    git add .
    git commit -m "dependências de desenvolvimento"
    git push
  fi
}

function configurar_documentacao() {
  mkdocs new .
  mkdir -p ./docs/assets ./docs/stylesheets ./docs/api
  touch ./docs/assets/logo.png ./docs/stylesheets/extra.css ./docs/api/$name_api.md
  echo "::: main" > ./docs/api/$name_api.md

  iniciais=$(echo "$projeto" | sed "s/-/ /g" | awk '{for(i=1;i<=NF;i++)print substr($i,1,1)}' | tr -d '\n')
  if command -v convert >/dev/null; then
    convert -size 100x100 xc:transparent -font Ubuntu -pointsize 72 -gravity center -draw "text 0,0 '$iniciais'" ./docs/assets/logo.png
  fi

  echo "site_name: $projeto" > mkdocs.yml
  if [[ "$isgit" == "y" ]]; then
    repo_url=$(git config --get remote.origin.url)
    echo "repo_url: $repo_url" >> mkdocs.yml
    IFS=":" read -ra partes <<< "$repo_url"
    repo_name=$(echo "${partes[-1]}")
    echo "repo_name: $repo_name" >> mkdocs.yml
    echo "edit_uri: tree/main/docs" >> mkdocs.yml
  fi

  cat <<EOF >> mkdocs.yml

theme:
  name: material
  language: pt-BR
  logo: assets/logo.png
  favicon: assets/logo.png

markdown_extensions:
  - attr_list

extra_css:
  - stylesheets/extra.css

plugins:
  - mkdocstrings:
      handlers:
        python:
          paths: [$name_api]
EOF
}

function gerar_main_py() {
  mkdir -p ./$name_api
  cat <<EOF > ./$name_api/main.py
"""$descricao"""
import json
import os
from fastapi import Depends, FastAPI, Response

app = FastAPI(
    title="$name_api",
    description="$descricao",
    version="0.1.0"
)

@app.get("/healthcheck")
async def healthcheck():
    return Response(
        content=json.dumps({
            "status": "ok",
            "message": "API is running",
            "version": app.version
        }),
        media_type="application/json"
    )
EOF
}

function configurar_pyproject() {
  cat <<EOF >> pyproject.toml

[tool.pytest.ini_options]
pythonpath = "."
addopts = ["--doctest-modules", "-p no:warning"]

[tool.ruff]
line_length = 79
exclude = [".venv", "migrations"]

[tool.ruff.lint]
preview = true
select = ["I", "F", "E", "W", "PL", "PT"]

[tool.ruff.format]
preview = true
quote-style = "double"

[tool.taskipy.tasks]
lint = "ruff check ."
format = "ruff format ."
run = "fastapi dev $name_api/main.py"
docs = "mkdocs serve"
pre_format = "ruff check --fix ."
pre_test = "task lint"
test = "pytest -s -x --cov=$name_api -vv"
post_test = "coverage html"
EOF
}

function exportar_requisitos() {
  poetry export --without-hashes --with dev -f requirements.txt -o requirements.txt
  if [[ "$isgit" == "y" ]]; then
    git add -p
    git commit -m "configuração das ferramentas de desenvolvimento"
    git push
  fi
}

### Execução do Script ###
exibir_apresentacao
ler_informacoes_projeto
instalar_dependencias
confirmar_remocao_diretorio
criar_estrutura_projeto
configurar_git
instalar_dependencias_python
gerar_main_py
configurar_documentacao
configurar_pyproject
exportar_requisitos

popd > /dev/null
exit 0
