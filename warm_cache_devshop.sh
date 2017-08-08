#!/bin/sh

PROC=5

./webtest.sh -h devshop.3dtotal.com -d -p $PROC -q "?"
./webtest.sh -h devshop.3dtotal.com -d -p $PROC -q "?force_country=US"
./webtest.sh -h devshop.3dtotal.com -d -p $PROC -q "?force_country=NL"
./webtest.sh -h devshop.3dtotal.com -d -p $PROC -q "?force_country=AU"

./webtest.sh -h devshop.3dtotal.com -d -p $PROC -q "?force_currency=USD"
./webtest.sh -h devshop.3dtotal.com -d -p $PROC -q "?force_currency=GBP"
./webtest.sh -h devshop.3dtotal.com -d -p $PROC -q "?force_currency=EUR"

./webtest.sh -h devshop.3dtotal.com -d -p $PROC -q "?force_country=US&force_currency=GBP"
./webtest.sh -h devshop.3dtotal.com -d -p $PROC -q "?force_country=US&force_currency=EUR"

./webtest.sh -h devshop.3dtotal.com -d -p $PROC -q "?force_country=NL&force_currency=GBP"
./webtest.sh -h devshop.3dtotal.com -d -p $PROC -q "?force_country=NL&force_currency=USD"

