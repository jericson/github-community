#!/usr/bin/env ruby -W1
# encoding: UTF-8

require 'httparty'
require 'json'
require 'htmlentities'
require 'date'
require 'pg'
require 'optparse'

options = {
  :github_token => ENV['GITHUB_TOKEN'],
  :query_limit => 120
}


optparse = OptionParser.new do |opts|
  opts.banner = "Usage: #{$0} user repo"

  opts.on("-g", "--github-token GITHUB_TOKEN", "GitHub API token") do |s|
    options[:github_token] = s
  end

  opts.on("-l", "--limit QUERIES", "Max queries for this run", Integer) do |s|
    options[:query_limit] = s
  end

end

optparse.parse!

if ARGV.length < 0 
  abort(optparse.help)
end

unless options[:github_token]
  abort(optparse.help)
end

mailmap = Hash.new

@user = ARGV.shift
@repo = ARGV.shift

@uri = URI("https://api.github.com/repos/#{@user}/#{@repo}/commits")

@more = true
@page = 1


while @more

  @uri.query = URI.encode_www_form({
                                     :per_page => 100,
                                     :page => @page
                                   })

  @response = HTTParty.get(@uri,
                           headers: { 'Authorization' => 'Bearer ' + options[:github_token],
                                      'Accept' =>  'application/vnd.github+json',
                                      'X-GitHub-Api-Version' => "2022-11-28"
                                    })
  case @response.code
  when 200
    JSON.parse(@response.body).each do |commit|
      
      email = '<' + commit['commit']['author']['email'] +'>'
      
      if commit['author'] then
        line = [
          commit['author']['login'],
          email
        ].join(" ")
      else
        line = [
          commit['commit']['author']['name'],
          email
        ].join(" ")
      end
      if mailmap[line]
        
        mailmap[line] += 1
      else
        mailmap[line] = 1
      end
    end
  when 403
  else
    STDERR.puts @uri, @response.body, @response.code, @response.message, @response.headers.inspect
  end
  

  STDERR.puts @response.headers['x-ratelimit-limit']
  STDERR.puts @response.headers['link']
  @more = /rel="next"/.match?@response.headers['link']
  @page += 1

  @more = false if @page > options[:query_limit]
end

puts mailmap.keys

