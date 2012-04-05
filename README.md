## Overview

This is an app to help promote the White House's Code Sprint for the Summer Jobs API
It showcases how to mark up job descriptions so they can be crawled by search engines and end up indexed by the US Department
of Labor's Summer Job Bank for the Youth.
It also showcases how to consume the the Jobs Bank API and allow visitors to perform queries.

In this app we showcase how to find jobs for your Facebook friends who are in the right age group (16-24)

For more information please read the [White House's blog post](http://www.whitehouse.gov/blog/2012/04/02/announcing-summer-jobs-code-sprint)


## Functionality
This is a boilerplate app which displays featured Summer Jobs at Cloud Foundry and allows visitors to search the
Department of Labor Summer Job Bank.

This app will show you how to consume the Department of Labor API.
You can register for a key and find more information about this at [http://developer.dol.gov/](http://developer.dol.gov/)

This template uses:

- Basic Sinatra
- haml
- 960gs
- Microdata

## To deploy on Cloud Foundry

Get an account at [https://my.cloudfoundry.com/signup/summerjobs](https://my.cloudfoundry.com/signup/summerjobs)

First fork the project. Then run:

``` bash
git clone git@github.com:<your_name>/summerjobs.git summerjobs
cd summerjobs
bundle install;bundle package
vmc push --nostart
```

## To configure

Set facebook and US Department of Labor API keys. See Developer Resources

``` bash
vmc env-add <app_name> facebook_app_id=23823782
vmc env-add <app_name> usdol_token=43823782
vmc env-add <app_name> usdol_secret="shared secret"
```

Then start the app with

    vmc start <app_name>

## Developer Resources

- [Register App and get API keys](https://webapps.dol.gov/developer)
- [Summer Jobs API Docs](http://developer.dol.gov/DOL-SUMMERJOBS-SERVICE.htm)
- [Job Schema](http://www.schema.org/JobPosting)
- [Test your microdata markup](http://www.google.com/webmasters/tools/richsnippets)

## Sample references

Original Ruby Sample App from DOL [http://developer.dol.gov/RubySamples.htm](http://developer.dol.gov/RubySamples.htm)

