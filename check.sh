#!/bin/bash

if [ "$PASSED" = "false" ]; then
  echo "::error::Token threshold exceeded"
  exit 1
fi

echo "Token analysis passed"
