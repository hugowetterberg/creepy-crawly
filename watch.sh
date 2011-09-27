#!/usr/bin/env bash
cd `dirname $0`
coffee -wc *.coffee lib/*.coffee lib/public/*.coffee
