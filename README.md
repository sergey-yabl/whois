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
  <h3 align="center">Centralnic test assignment</h3>

  <p align="center">
    Centralnic test assignment
    <br />
    <br />
    <a href="https://github.com/sergey-yabl/whois/issues">Report Bug</a>
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
  </ol>
</details>



<!-- ABOUT THE PROJECT -->
## About The Project

This is Centralnic test assignment

### TASK 1
Create a program which reads the file 'domains.txt', queries the whois service for each domain and prints out a list. 

```
#The list should contain the domain name and the domain status, example:
#domain;status
#key-systems.org;clientDeleteProhibited,clientTransferProhibited
#etc.
```

### TASK 2
Add the expiration date, for each domain, as well as the  (in the program) calculated amount of days,

```
#from today until the expiration date, example:
#domain;status;expirationdate;days until expirationdate
#key-systems.org;clientDeleteProhibited,clientTransferProhibited;2015-11-12 14:42:38;22
#etc.
```

<!-- GETTING STARTED -->
## Getting Started

### Installation
 - Install packages
   ```sh
   sudo apt install libyaml-libyaml-perl
   sudo apt-get install -y git cpanminus gcc   
   ```
   
 - Install CPAN packages
   ```sh
   sudo cpanm Log::Log4perl      \
     YAML::XS                    \
     JSON                        \
     Data::Validate::Domain      \
     DateTime::Format::RFC3339   \
     Net::Whois::Raw
   ```
 - Clone the repo
   ```sh
      git clone git@github.com:sergey-yabl/whois.git
   ```
 - Setup settings
	1. Go to the project dir  ```cd whois```
	2. Copy file ```cp conf/whois.conf.example conf/whois.conf```
	3. Check and update whois servers at the whois.conf if necessary
	4. Make the log directory: ```mkdir log```

<!-- USAGE EXAMPLES -->
## Usage

```sh
./runner.pl --limit 1000 --threads 8
./list.pl --in domains_list
   ```
It's going to read domains from input file, queries whois requests and print stdout domain name and it's flags like that:
```
domain;status
key-systems.org;clientDeleteProhibited,clientTransferProhibited
key-systems.info;clientTransferProhibited
...
```

NOTE: if there is a whois request error, the message would be placed at the "status" position:
```
domain;status
rrpproxy.mobi;ERROR: TIMEOUT
```


```sh
./list.pl --in domain_list --extend
   ```
It's going to do the same as example above with additional info: domain expiration datetime (GMT) and days number before domain expired. For example:

```
domain;status;expiration date;days
key-systems.org;clientDeleteProhibited,clientTransferProhibited;2022-11-12 14:42:38;230
key-systems.info;clientTransferProhibited;2022-07-31 17:05:12;126
...
```

NOTE: if there is a problem with determine expiration date and days, those values would be replaced with hyphens:
```
domain;status;expiration date;days
rrpproxy.biz;clientTransferProhibited;-;-
```


### Synopsys
```sh
list.pl [--in <path>] [--extend] [--debug]

  Options:
    --help:        Print a summary of the command-line usage and exit.
    --in:          Path to a file with domain names list (one domain per line).
    --extend:      Print out extend info: expiration date and calculated amount of days
    --debug:       Each request/response body are going to logging.
```

<!-- LOG FILES -->
### Log files
#### whois.log
Template:
```
%timestamp% %pid% %event-type% %message%
```
Example:
```
2022-03-27 01:09:15 pid:66435 INFO Get whois info for the domain "key-systems.org"
2022-03-27 01:09:16 pid:66435 INFO Whois server: whois.pir.org
2022-03-27 01:09:16 pid:66435 INFO Success getting whois info
2022-03-27 01:09:16 pid:66435 INFO Get whois info for the domain "key-systems.info"
...
2022-03-27 01:09:48 pid:66435 INFO Process completed. File lines: 12; domains: 10; success whois requests: 9
```
#### debug.log
Is used for store whois responses for further investigation.
It is only works with --debug input param




