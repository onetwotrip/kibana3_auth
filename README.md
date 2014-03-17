# Kibana 3 Auth
## Introduction

Kibana3 is a pure JavaScript application and doesn't provide any form of user isolation or authentication. The Kibana3 Auth is a small ruby Rack/Sinatra proxy which was written to supply these functionality.

## Features

x

## Installation and setup

### Step 1. Clone kibana3_auth and kibana source

    $ git clone https://github.com/dennybaa/kibana3_auth.git
    $ cd kibana3_auth
    $ git submodule init && git submodule update
    $ bundle install --without development

### Step 2. Install nginx and configure proxing

    $ sudo apt-get install nginx
    $ sudo cp samples/nginx.conf /etc/nginx/sites-available/kibana_auth
    $ $EDITOR /etc/nginx/sites-available/kibana_auth # CUSTOMIZE!
    $ nginx -t && sudo /etc/init.d/nginx reload

### Step 3. Customize ElasticSearch location in config.js

If ElasticSearch is not located on the localhost you must customize the following option in config.js:

    * ==== elasticsearch
     *
     * The URL to your elasticsearch server. You almost certainly don't
     * want +http://localhost:9200+ here. Even if Kibana and Elasticsearch are on
     * the same host. By default this will attempt to reach ES at the same host you have
     * kibana installed on. You probably want to set it to the FQDN of your
     * elasticsearch host
     */
    elasticsearch: "http://" + window.location.hostname + ":9200",

set the **elasticsearch** key to the correct url of your ElasticSearch instance.

### Step 4. Configure Kibana3 Auth and Start.

Minimum to go set the following content in *kibana3_auth/config.rb*.

    {
        logging:        true,
        log_level:      'info',
        session_secret: 'CHANGE_ME',
        auth_file:      '/etc/nginx/conf.d/kibana.htpasswd'
    }

The two options are very desired to be defined: **session_secret**, **auth_file**.

Start Kibana3 Auth:

    $ rackup config.ru


## Kibana3 Auth configuration.

Configuration file *config.rb* contains ruby hash containing application options. The overview is provided bellow:

 * __kibana_root__      -   kibana source root. If the submodule was checkedout along with kibana3_auth the path is *kibana/src*. Default is `"kibana/src"`.
 * __login_header__     -   login dialog header. Default is `"Kibana3 Login"`.
 * __logging__          -   enables/disables logging. Default is `true`.
 * __log_level__        -   log level/verbosity. Default is `:info`.
 * __auth_method__      -   authentication method. *HTTP Basic Authentication* is **only supported**. Default is `:basic`.
 * __auth_realm__       -   authentication realm. Defaul is `"Restricted Area"`.
 * __auth_file__        -   path to authentication file. Default is `"htpasswd"`.
 * __session_domain__   -   session cookie domain. Default is `nil`.
 * __session_expire__   -   session cookie experation time. Default is `7200` (*2 hours*).
 * __session_secret__   -   session secure secret, must be set to a random value. Default is `"change_me"`.
