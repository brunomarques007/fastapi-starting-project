#!/bin/bash -i

# Copyright (c) 2023 bruno.marques
# 
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

# Apresentação projeto python
[ $(which figlet) ] || sudo apt-get install figlet
echo -e "\033[1;39;104m $(figlet Projeto Python) \033[0m \n"
echo -e "\033[1;93m"
echo -e 'Olá, qual é o nome do projeto? Favor usar - ao invés de _. \033[m'

# Aqui é solicitado o nome do projeto
read -p 'Nome do Projeto: ' projeto


echo -e "\n\033[1;30;103m\U26A0 Atenção \U26A0 \033[m"
echo -e "\033[1;39;41m"
echo -e "Caso exista um diretório com o mesmo nome do projeto, este será removido.\033[m"

echo -e "\033[1;94m"
echo -e "\U1F60E Legal! Iniciando o projeto\033[m \033[1;3m $projeto \033[m"
sleep 5

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
echo -e "\033[1m \n\n"
echo -e "Terminando as validações e iniciando o projeto \U1F60E \033[0m"

# removendo diretório caso exista
rm -rf $projeto
poetry new $projeto

# Acessa o diretório criado para iniciar o ambiente virtual
cd $projeto
path=$(pwd)
echo -e "\033[1m \n"
echo 'Acessando o diretório do projeto: \033[0m'$path
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
poetry add --group dev ruff
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
touch ./docs/assets/logo.png
mkdir ./docs/stylesheets
mkdir ./docs/api
touch ./docs/api/sua_api.md
touch ./docs/stylesheets/extra.css

# Inicias do projeto para o logo
iniciais=$(echo $projeto | sed "s/-/ /g" | awk '{for(i=1;i<=NF;i++)print substr($i,1,1)}' | tr -d '\n')

# Verifica se o convert está instalado e cria o logo
if [ $(which convert) ]; then
    convert -size 100x100 xc:transparent -font Ubuntu -pointsize 72 -gravity center -draw "text 0,0 '$iniciais'" ./docs/assets/logo.png >> /dev/null
fi

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

#configurando o ruff
echo '
[tool.ruff]
line_length = 79
exclude = [".venv", "migrations"]' >> pyproject.toml

#configurando o isort para trabalhar com o blue
echo '
[tool.isort]
profile = "black"
line_length = 79' >> pyproject.toml

#criando tasks do taskipy
printf '
[tool.taskipy.tasks]
lint = "ruff --check --diff . && isort --check --diff ."
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
