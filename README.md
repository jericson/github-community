# GitHub Community

Tools for managing a GitHub community.

## mailmap

A key tool for analyzing contributions is `git log`. By default, the
log doesn't attempt to 

```
sqlite> .import commits.csv authors --csv
```

```
select author, max(date), count(*) 
from authors 
group by author 
having max(date) between date('now','start of month','-1 month') 
                 and date('now','start of month', '-1 days') 
       and count(*) = 1 
order by max(date);
```


## See also

* I learned a lot from [curl's stats scripts](https://github.com/curl/stats)
