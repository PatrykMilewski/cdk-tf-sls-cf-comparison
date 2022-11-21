#!/bin/sh

which terraform && exit 0

brew tap hashicorp/tap
brew install hashicorp/tap/terraform
