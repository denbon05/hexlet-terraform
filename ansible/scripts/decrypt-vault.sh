#!/bin/bash

for vault_path in $(find . -type f -name vault.yml)
do
  ansible-vault decrypt $vault_path
done