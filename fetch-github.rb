#!/usr/bin/env ruby -W1
# encoding: UTF-8

require 'httparty'
require 'json'
require 'csv'
require 'htmlentities'
require 'date'
require 'pg'
require 'optparse'

options = {
  :github_token => ENV['GITHUB_TOKEN'],
  :query_limit => 120,
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

  opts.on("-c", "--cache-file", "File to cache results") do |s|
    options[:cache_file] = s
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

@uri = URI("https://api.github.com/repos/#{@user}/#{@repo}/issues")

@more = true
@page = 1



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
      issue = body.first
    else
      issue = body
    end
    issue['author'] = issue['user']['login']
    issues[issue['number']] = issue
  when 403
  else
    STDERR.puts @uri, @response.body, @response.code, @response.message, @response.headers.inspect
  end
  

  #STDERR.puts @response.headers['x-ratelimit-limit']
  #STDERR.puts @response.headers['link']

  return @response.headers['x-ratelimit-limit']
  
end

@uri.query = URI.encode_www_form({
                                   :per_page => 1,
                                   :sort => 'created',
                                   :direction => 'desc'
                                 })



fetch_issue(@uri, issues, options)

for i in 1..issues.keys.max
  break if @page > options[:query_limit]
  next if issues[i];
  @page += 1
  
  @uri = URI("https://api.github.com/repos/#{@user}/#{@repo}/issues/#{i}")

  ret=fetch_issue(@uri, issues, options)
  break if ret.to_i < 100
  
end

fields = ['number', 'title', 'author', 'state', 'created_at', 'closed_at', 'updated_at', 'author_association', 'comments']

File.write(options[:cache_file], fields.to_csv)

issues.sort.to_h.values.each do |i|
  row =  i.slice('number', 'title', 'author', 'state', 'created_at', 'closed_at', 'updated_at', 'author_association', 'comments').values.to_csv
  File.write(options[:cache_file], row, mode: 'a')
end


#pp issues
