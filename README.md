Список пакетов
   sudo apt-get install -y git cpanminus gcc

 - Install CPAN packages
   ```sh
   sudo apt-get install -y git cpanminus gcc
   sudo cpanm IO::Socket::SSL    \
     HTTP::Request               \
     LWP::Protocol::https        \
     LWP::UserAgent              \
     Time::HiRes                 \
     Log::Log4perl               \
     YAML::XS                    \
     JSON                        \
     Data::Validate::Domain      \
     DateTime::Format::RFC3339   \
     Net::Whois::Raw
   ```


<!--
*** Thanks for checking out the Best-README-Template. If you have a suggestion
*** that would make this better, please fork the repo and create a pull request
*** or simply open an issue with the tag "enhancement".
*** Thanks again! Now go create something AMAZING! :D
***
***
***
*** To avoid retyping too much info. Do a search and replace for the following:
*** github_username, repo_name, twitter_handle, email, project_title, project_description
-->



<!-- PROJECT SHIELDS -->
<!--
*** I'm using markdown "reference style" links for readability.
*** Reference links are enclosed in brackets [ ] instead of parentheses ( ).
*** See the bottom of this document for the declaration of the reference variables
*** for contributors-url, forks-url, etc. This is an optional, concise syntax you may use.
*** https://www.markdownguide.org/basic-syntax/#reference-style-links
-->

<!-- PROJECT LOGO -->
  <h3 align="center">EPP Load Testing</h3>

  <p align="center">
    EPP load testing service
    <br />
    <br />
    <a href="https://git.vrteam.ru/srs/EppLoader/-/issues">Report Bug</a>
  </p>
</p>



<!-- TABLE OF CONTENTS -->
<details open="open">
  <summary><h2 style="display: inline-block">Table of Contents</h2></summary>
  <ol>
    <li>
      <a href="#about-the-project">About The Project</a>
    </li>
    <li>
      <a href="#getting-started">Getting Started</a>
      <ul>
        <li><a href="#installation">Installation</a></li>
      </ul>
    </li>
    <li><a href="#usage">Usage</a></li>
    <li><a href="#log-files">Log files</a></li>
    <li><a href="#result">Result</a></li>
  </ol>
</details>



<!-- ABOUT THE PROJECT -->
## About The Project

The service provide you to do EPP login, send serial "check" requests and get a result statistic. The script language is Perl.

<!-- GETTING STARTED -->
## Getting Started

### Installation
 - Install packages
   ```sh
   sudo apt install libnet-ssleay-perl
   sudo apt install libyaml-libyaml-perl
   ```
 - Install CPAN packages
   ```sh
   sudo apt-get install -y git cpanminus
   sudo cpanm IO::Socket::SSL \
     HTTP::Request            \
     LWP::Protocol::https     \
     LWP::UserAgent           \
     Time::HiRes              \
     Log::Log4perl            \
     YAML::XS                 \
     JSON
   ```
 - Clone the repo
   ```sh
      git clone git@github.com:sergey-yabl/testing.git
   ```
 - Setup settings
	1. Go to the project dir  ```cd EppLoader```
	2. Copy file ```cp conf/load.conf.example conf/load.conf```
	3. Place a client's certificate and key in the conf directory
	4. Edit config ```conf/load.conf``` and setup params:
		 - EPP API address
		 - API login and password
		 - path for a client's certificate and key
		 - registrant name (contact) for domain created request
		 - req_ratio for check/create request proportion
		 - domains number range for a check requests
		 - user agent name for logging purpose
	5. Make the log directory: ```mkdir log```

<!-- USAGE EXAMPLES -->
## Usage

```sh
./runner.pl --limit 1000 --threads 8
   ```
It's going to send 1000 request in 8 threads.

```sh
./runner.pl --time 10 --debug
   ```
It's going to send request for 10 seconds and print all request/response data to the request.log.


### Synopsys
```sh
runner.pl [--limit <n>]  [--time <sec>] [--threads <n> ]

  Options:
    --help:        Print a summary of the command-line usage and exit.
    --limit:       Exit when <n> requests have sent.
    --time:        Exit wnen <sec> passed.
    --threads:     Use <n> threads for EPP requests, default = 1
    --config:      Path to the configuration file, default conf/load.conf.
    --debug:       All request/response body are going to be logged.
```

<!-- LOG FILES -->
### Log files
#### loaded.log
Template:
```
%timestamp% %pid% %event-type% %epp-command% %status% %elapsed% %cltrid% %cvtrid%
```
Example:
```
2021-04-02 11:43:47 pid:20449 INFO CHECK success 0.0126 cltrid:1617353026.993757@test.epp.yabl svtrid:3925071047
2021-04-02 11:43:47 pid:20449 ERROR LOGOUT failed 0.0121 cltrid:1617353027.2610@test.epp.yabl svtrid:3925071052
```
#### request.log
Is used for store request and response body when we got and error.
You can search request by svtrid that could be found in a loaded.log file.
Template:
```
%timestamp%
%request direction% %request-id%
%request headers%
%request body%

%response direction% %request-id%
%response headers%
%response body%
```

<!-- RESULT STATISTIC -->
### Result
When all request have been sent, the statistics will be showed.
For example:

```
Total requests: 844482 (success: 844585, error: 1)
  Check requests: 0 (success: 0, error: 0)
  Create requests: 5000 (success: 5000, error: 0)
Total time: 1808 sec. (22:40:00 - 23:10:08)
Elapsed:
   max: 31.6251 / 1617351408.274685@test.epp.yabl
   min: 0.0103
   avr: 0.0168

RPS:
   max: 600
   min: 0
   avr: 467

The worst          The best
31 - 1             0.010 - 23
15 - 13            0.011 - 72427
3 - 192            0.012 - 320217
1 - 1861           0.013 - 266570
0.418 - 1          0.014 - 77007
0.403 - 1          0.015 - 36286
0.402 - 1          0.016 - 12752
0.401 - 1          0.017 - 7202
0.398 - 1          0.018 - 5485
0.395 - 1          0.019 - 7225
```
where: 
- ```Total requests``` - the total number of request that have been send
- ```Check/Create requests``` - the check/create request number
- ```Total time```     - how much time the test have taken
- ```Elapsed```     - request's elapsed time statistic
- ```RSP```     - request's rps statistic
- ```The worst``` and ```The best```     - top 10 best and worst times and request numbers each of them.

## NOTE: 
- The result code 2302 (domain exists) of domain create request is considered as success because its a normal situation.
- Request and response body of errors request would be dumped into the log/request.log file.



