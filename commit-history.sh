echo sha,date,author,email,subject > openssl_commit.csv && git log --pretty=format:'%h,%aI,"%aN","%ae","%f"' >> openssl_commit.csv
