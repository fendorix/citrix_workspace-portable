#!/bin/sh
export ICAROOT=/opt/Citrix/ICAClient
export MESA_SHADER_CACHE_DISABLE=true
exec ${ICAROOT}/wfica -file "$1"
