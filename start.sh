#!/bin/bash -i

# Copyright (c) 2023 bruno.marques
# 
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

# Aqui é solicitado o nome do projeto
echo Olá, qual é o nome do projeto? Favor usar - ao invés de _.
read -p 'Nome do Projeto: ' projeto

echo Legal iniciar o projeto $projeto

# Nome do diretório que será criado pelo poetry
# e que vamos usar mais a frente
name_api=$(echo $projeto | sed "s,-,_,g")

# Aqui validamos se o python e o pip estão instalados
sudo apt-get update > /dev/null & wait
[ $(which python3) ] || sudo apt-get install python3
[ $(which pip) ] || sudo apt-get install python3-pip
[ $(which git) ] || sudo apt-get install git
[ $(which gh) ] || sudo apt-get install gh

#Aqui instalamos os pacotes do python para iniciar um projeto
[ $(which pipx) ] || pip install pipx
[ $(which poetry) ] || pipx install poetry
[ $(which ignr) ] || pip install ignr

# Aqui inicia o projeto
echo Iniciando o projeto
poetry new $projeto

# Acessa o diretório criado para iniciar o ambiente virtual
cd $projeto
path=$(pwd)
echo 'Acessando o diretório do projeto: '$path
# Inicia o ambiente virtual
poetry shell & wait >> /dev/null
#source $(poetry env info --path)/bin/activate

# Aqui inicia o repositório no GIT
read -p 'Deseja utilizar o git? [y/n]: ' isgit
if [[ $isgit == 'y' ]]; then
    git init #inicia o projeto
    ignr -p python > .gitignore #cria o arquivo .gitignore padrão python
    gh auth login #autentica no git
    gh repo create #cria o repositório remoto
    git commit -m "Commit inicial, estrutura do projeto"
    git push --set-upstream origin main
fi

#Criando o ambiente de dev
poetry add --group dev blue
poetry add --group dev isort
poetry add --group dev pytest
poetry add --group dev pytest-cov
poetry add --group dev pytest-blue
poetry add --group dev taskipy

#criando o ambiente de documentação
poetry add --group doc mkdocs
poetry add --group doc mkdocs-material
poetry add --group doc mkdocstrings
poetry add --group doc mkdocstrings-python

#atualizando o git com as dependências
if [[ $isgit == 'y' ]]; then
    git add .
    git commit -m "dependências de desenvolvimento"
    git push
fi

#ajustando o tema e as configurações do mkdocs
mkdocs new .
mkdir ./docs/assets
mkdir ./docs/stylesheets
mkdir ./docs/api
touch ./docs/api/sua_api.md
touch ./docs/stylesheets/extra.css
echo 'site_name: '$projeto > mkdocs.yml
if [[ $isgit == 'y' ]]; then
    repo_url=$(git config --get remote.origin.url)
    echo 'repo_url: '$repo_url >> mkdocs.yml
    IFS=":" read -ra partes <<< "$repo_url"
    repo_name=$(echo "${partes[-1]}")
    echo 'repo_name: '$repo_name >> mkdocs.yml
    echo 'edit_uri: tree/main/docs'
fi

printf '
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
          paths: [%s]' "$name_api" >> mkdocs.yml

#configurando o pytest
echo '
[tool.pytest.ini_options]
pythonpath = "."
addopts = "--doctest-modules"' >> pyproject.toml

#configurando o isort para trabalhar com o blue
echo '
[tool.isort]
profile = "black"
line_length = 79' >> pyproject.toml

#criando tasks do taskipy
printf '
[tool.taskipy.tasks]
lint = "blue --check --diff . && isort --check --diff ."
docs = "mkdocs serve"
pre_test = "task lint"
test = "pytest -s -x --cov=%s -vv"
post_test = "coverage html"' "$projeto" >> pyproject.toml

#criando o arquivo requeriments.txt
poetry export --without-hashes --with dev -f requirements.txt -o requirements.txt

#atualizando o git com as dependências
if [[ $isgit == 'y' ]]; then
    git add -p
    git commit -m "configuração das ferramentas de desenvolvimento"
    git push
fi

exit
