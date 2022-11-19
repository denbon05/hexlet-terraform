#!/bin/bash

for vault_path in $(find . -type f -name vault.yml)
do
  ansible-vault encrypt $vault_path
done