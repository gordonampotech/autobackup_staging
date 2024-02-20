#!/bin/sh

# Start Nginx with specified options
nginx -g 'daemon off; error_log /dev/stdout debug;' &

# Start the Flask app in the background
flask run --host=0.0.0.0 &

# Execute your shell script
./api.sh

wait
