# GitHub Community

Tools for managing a GitHub community.

## mailmap.rb

A key tool for analyzing Git contributions is `git log`. By default,
the log doesn't attempt to sort out people who use more than one email
address or nicknames. But if you have a [`.mailmap`
file](https://git-scm.com/docs/gitmailmap), `git log` will used that
to group people according to a canonical name and email. GitHub has
[an API for listing
commit](https://docs.github.com/en/rest/commits/commits?apiVersion=2022-11-28)
and it can be used to map names and email address to GitHub handles. I
can use several emails or change my name in commit messages and still
have one GitHub account.

The `mailmap.rb` script uses the GitHub API to create a `.mailmap`
file in the repository directory:

```
../mailmap.rb > .mailmap
```

## commit-history.sh

Just a quick shell script to:

1. Extract commit information from `git log` and
2. Populate an `authors` table in a SQLite database (`community.db`).

This allows me to do fun things like find new contributors from the
last month:

```
select author, max(date), count(*) 
from authors 
group by author 
having max(date) between date('now','start of month','-1 month') 
                 and date('now','start of month', '-1 days') 
       and count(*) = 1 
order by max(date);
```

## tag-collect.sh

If a project tags it's releases, this script is useful for collecting
data about the code over history. It checks out the tagged release and
uses [`cloc`](https://github.com/AlDanial/cloc) to count:

* lines of code,
* lines of documentation and
* lines of tests.

It also uses `cloc`'s mechanism for populating a SQLite database
(`community.db`). In the end you'll have 3 "projects":

1. `$tag`, which is just the tagged release's code.
2. `tag.doc`, which is the tagged release's documentation.
3. `tag.test`, which is the tagged release's tests.

This script is fairly specific to OpenSSL, but I'm expanding it to
curl as I have a moment so that I can find some points that need
configuration. 

To collect all the OpenSSL 3.x release data, I use:

```
git tag --list | grep 'openssl-3...0$' | xargs -n 1 ../tag-collect.sh
```

That will allow me to produce reports like this one:

```
sqlite3 community.db '.headers on' '.mode markdown' 'select project, sum(nCode) lines from t group by project order by project'
```

|      Project       |  lines  |
|--------------------|---------|
| openssl-3.0.0      | 866134  |
| openssl-3.0.0.doc  | 73981   |
| openssl-3.0.0.test | 258460  |
| openssl-3.1.0      | 906182  |
| openssl-3.1.0.doc  | 75850   |
| openssl-3.1.0.test | 268322  |
| openssl-3.2.0      | 1026420 |
| openssl-3.2.0.doc  | 95957   |
| openssl-3.2.0.test | 304292  |
| openssl-3.3.0      | 1048545 |
| openssl-3.3.0.doc  | 98325   |
| openssl-3.3.0.test | 310239  |
| openssl-3.4.0      | 1070618 |
| openssl-3.4.0.doc  | 102332  |
| openssl-3.4.0.test | 318514  |
| openssl-3.5.0      | 1151443 |
| openssl-3.5.0.doc  | 109693  |
| openssl-3.5.0.test | 362576  |

## fetch-github.rb

A lot of community happens in GitHub issues, discussions and pull
requests. This script attempts to pull all this data from GitHub. It's
a lot of data and you will need to have a [GitHub API
token](https://docs.github.com/en/rest/authentication/authenticating-to-the-rest-api?apiVersion=2022-11-28)
to avoid the most restrictive rate limits. The code is still in flux,
but it does have an option to save the results in JSON files to avoid
hitting the API too much. Once you have a complete collection, it's
possible to get the updated items using something like:

```
./fetch-github.rb openssl openssl -j openssl_cache --updates
```

Again, this populates a SQLite database (`community.db`) which can be
queried. For instance, here's a bit of SQL to report how many issues,
PRs and discussion threads were started each month:

```
select count(*) issue_count, 
       sum(comments) comments,
       strftime('%Y-%m-1', created_at) month,
       type
from issues
where month < strftime('%Y-%m-1', 'now')
group by strftime('%Y-%m-1', created_at), type
```

## See also

* I learned a lot from [curl's stats
  scripts](https://github.com/curl/stats). There are a lot of charts
  there that I'd like to duplicate. One thing I don't care for is the
  duplicate code and that so much is hardcoded.

