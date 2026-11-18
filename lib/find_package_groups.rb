#!/bin/env ruby

require "octokit"
require "dotenv/load"
require "json"
require "optparse"

options = {}
OptionParser.new do |parser|
  parser.banner = "Usage: find_package_groups [options]"

  parser.on("-v VERSION", "--version=VERSION", "Set Version to look for") do |v|
    options[:version] = v
  end

  parser.on("-r REF", "--ref=REF", "Use ref instead of default branch") do |ref|
    options[:ref] = ref
  end

  parser.on("-p PREFIX", "--prefix=PREFIX", "path prefix for packages in repo [packages]") do |prefix|
    options[:prefix] = prefix
  end
end.parse!

slug = ARGV[0]

if slug.nil? || slug.strip == ""
  puts "Depfu's Package Group finder. Automate ALL THE THINGS!"
  puts
  puts "Usage: find_package_groups [options] [slug]"
  puts "slug is GitHub repo slug (e.g. flowbyte/package_group_finder)"
  puts
  exit 1
end

octokit_options = {
  access_token: ENV['GITHUB_ACCESS_TOKEN']
}

client = Octokit::Client.new(octokit_options)

ref = options[:ref] || client.repo(slug).default_branch
puts "Using repo: #{slug}"
puts "Using ref: #{ref}"

prefix = options[:prefix] || "packages"

all = client.contents(slug, path: prefix, ref: ref, accept: "application/vnd.github.v3.object")

dirs = all.entries.select {|e | e.type == "dir" }.map(&:path)

packages = dirs.map do |dir|
  package_json = client.contents(slug, path: File.join(dir, "package.json"), ref: ref, accept:"application/vnd.github.v3.raw")
  parsed = JSON.parse(package_json)
  { name: parsed["name"], version: parsed["version"] }
end

version_to_group = options[:version] || packages.find {|p| !p[:version].nil? }[:version]

puts "Using #{version_to_group} as canonical version."

puts packages.select{|p| p[:version] == version_to_group }.map{|p| %Q["#{p[:name]}"]}.join(",\n")
