#!/usr/bin/env ruby -W1
# encoding: UTF-8

require 'httparty'
require 'json'
require 'csv'
require 'htmlentities'
require 'date'
require 'pg'
require 'optparse'
require 'fileutils'

options = {
  :github_token => ENV['GITHUB_TOKEN'],
  :query_limit => 2000,
  :cache_file => 'issues.csv'
}


optparse = OptionParser.new do |opts|
  opts.banner = "Usage: #{$0} user repo"

  opts.on("-g", "--github-token GITHUB_TOKEN", "GitHub API token") do |s|
    options[:github_token] = s
  end

  opts.on("-l", "--limit QUERIES", "Max queries for this run", Integer) do |s|
    options[:query_limit] = s
  end

  opts.on("-c", "--cache-file FILE", "File to cache results") do |s|
    options[:cache_file] = s
  end

  opts.on("-j", "--json-dir DIRECTORY", "Directory for saving JSON versions of issues") do |s|
    options[:json_dir] = s
  end

  opts.on("-u", "--updates", "Fetch the latest updates") do |s|
    options[:updates] = s
  end

end

optparse.parse!

if ARGV.length < 0 
  abort(optparse.help)
end

unless options[:github_token]
  abort(optparse.help)
end

issues = Hash.new

if File.file?(options[:cache_file])
  CSV.foreach(options[:cache_file], headers: true) do |row|
    issues[row['number'].to_i] = row.to_h()
  end
end

@user = ARGV.shift
@repo = ARGV.shift


@more = true
@page = 1

def insert_issue(issue, issues, options)

  if options[:json_dir]
    if FileUtils.mkdir_p(options[:json_dir])
      File.write(File.join(options[:json_dir], "#{issue['number']}.json"),
                 issue.to_json)
    end
  end
  
  issue['author'] = issue['user']['login']

  if issue['html_url'] =~ %r"^https://github.com/[^/]+/[^/]+/([^/]+)/\d+$"
    issue['type'] = $1
  end

  if issue['type'] == 'discussions'
    issue['closed_at'] = ''
  end

  issues[issue['number']] = issue
end

def fetch_issue(uri, issues, options)
  @response = HTTParty.get(uri,
                           headers: { 'Authorization' => 'Bearer ' + options[:github_token],
                                      'Accept' =>  'application/vnd.github+json',
                                      'X-GitHub-Api-Version' => "2022-11-28"
                                    })
  case @response.code
  when 200
    body= JSON.parse(@response.body)
    if body.kind_of?(Array)
      body.each do |issue|
        insert_issue(issue, issues, options)
      end
    else
      issue = body
    
      insert_issue(issue, issues, options)
    end
  when 404
    return 404
  else
    STDERR.puts @uri, @response.body, @response.code, @response.message, @response.headers.inspect
  end
  

  #STDERR.puts @response.headers['x-ratelimit-limit']
  #STDERR.puts @response.headers['link']

  return @response
  
end

@uri = URI("https://api.github.com/repos/#{@user}/#{@repo}/issues")

while @more
  @uri.query = URI.encode_www_form({
                                     :per_page => 100,
                                     :page => @page,
                                     :sort => 'updated',
                                     :direction => 'desc'
                                   })

  ret = fetch_issue(@uri, issues, options)

  STDERR.puts ret.headers['x-ratelimit-limit']
  STDERR.puts ret.headers['link']
  @more = /rel="next"/.match?ret.headers['link']
  @page += 1

  @more = false unless options[:updates]
  @more = false if @page > options[:query_limit]
end

#for i in 21355..issues.keys.max # Test first discussion
for i in 1..issues.keys.max
  break if @page > options[:query_limit]
  next if issues[i];
  @page += 1

  if options[:json_dir]
    path = File.join(options[:json_dir], "#{i}.json")
    if File.file? path
      file = File.open path
      issue = JSON.load file
      insert_issue(issue, issues, options)
      next
    end
  end
  
  @uri = URI("https://api.github.com/repos/#{@user}/#{@repo}/issues/#{i}")

  ret=fetch_issue(@uri, issues, options)

  if ret == 404
    @discussion_uri = URI("https://api.github.com/repos/#{@user}/#{@repo}/discussions/#{i}")
    ret = fetch_issue(@discussion_uri, issues, options)
  end

  next if ret == 404
  
  break if ret.headers['x-ratelimit-limit'].to_i < 100
  
end

fields = ['number', 'title', 'type', 'author', 'state', 'created_at', 'closed_at', 'updated_at', 'author_association', 'comments']

File.write(options[:cache_file], fields.to_csv)

issues.sort.to_h.values.each do |i|
  row =  i.slice('number', 'title', 'type', 'author', 'state', 'created_at', 'closed_at', 'updated_at', 'author_association', 'comments').values.to_csv
  File.write(options[:cache_file], row, mode: 'a')
end


#pp issues
