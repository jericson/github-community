echo sha,date,author,email,subject > commits.csv && git log --pretty=format:'%h,%aI,"%aN","%ae","%f"' >> commits.csv
