# Evernote Spider
This is an Evernote API's utility.
Aim to store notes to local database for blog application.

Features:
- Get auth token (access token) easily
- Convert Notes formatting: XML -> HTML

## Installation & Usage

      % cd evernote_spider/

      % rvm use 1.9.3
      % bundle install

      % cp config.yml.sample config.yml
      % vim config.yml
        -> fill up config.yml
           visit https://dev.evernote.com/ and get an API key

      % rake get_access_token
      retrieve access token from sandobox.evernote.com ...
      access token: *****

      % vim config.yml
        -> add above access token to config.yml

      % rake notebooks
