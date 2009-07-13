#!/usr/bin/ruby

# José M. Prieto <jmprieto@gmx.net> wrote this file. As long as you retain
# this notice you can do whatever you want with this stuff. If we meet some
# day, and you think this stuff is worth it, you can buy me a beer in return.

require 'rubygems'
require 'mechanize'
require 'csv'
require 'yaml'
require 'optparse'

CONFIG_FILE = "config.yml"
LOGIN_URL = "/login"
TIMELOG_URL = "/timelog/edit?issue_id="
DATE_FORMAT = '%d/%m/%y'

class Redmine
  def initialize(url, username, password)
    @url = url
    @username = username
    @password = password
    @mech = WWW::Mechanize.new
  end

  def login
    @mech.get @url + LOGIN_URL
    form = @mech.page.forms[1]
    form.username = @username
    form.password = @password
    form.click_button
  end

  def timelog(issue, date, time)
    @mech.get @url + TIMELOG_URL + issue
    form = @mech.page.forms[1]
    form.field_with(:name => 'time_entry[spent_on]').value = date
    form.field_with(:name => 'time_entry[hours]').value = time
    form.click_button
  end
end

class DryRedmine
  def login
  end

  def timelog(issue, date, time)
    puts "#{date},#{issue},#{time}"
  end
end

class RowParser
  attr_accessor :row

  def initialize(replaces, ignores)
    @replaces = replaces
    @ignores = ignores
  end

  def time
    if @row[5] =~ /^([0-9]+:[0-9]+):/
      $1
    else
      @row[5]
    end
  end

  def date
    Date.strptime(@row[0], DATE_FORMAT).to_s
  rescue ArgumentError
    @row[0]
  end

  def task
    if @replaces
      @replaces.each do |key, value|
        if key =~ /^\/.*\/$/ and @row[1].match(key[1..-2]) or @row[1] == key
          return (eval value.to_s).to_s
        end
      end
    end
    @row[1]
  end

  def ignored?
    if @ignores
      @ignores.each do |ignore|
        if ignore =~ /^\/.*\/$/ and @row[1].match(ignore[1..-2]) or @row[1] == ignore
          return true
        end
      end
    end
    false
  end
end

def each_row(csv)
  if csv.is_a? File
    CSV::Reader.parse(csv) { |row| yield row }
  elsif csv.is_a? Array
    csv.each { |row| yield row }
  end
end

def parse_args
  options = { 'dry-run' => false }
  OptionParser.new do |parse|
    parse.banner = "Usage: #{$0} [OPTION]..."
    parse.separator nil
    parse.separator 'Options:'
    parse.on('-n', '--dry-run', 'Do nothing, just print out the timelog ' +
             'entries that will be created') do
      options['dry-run'] = true
    end
    parse.on_tail('-h', '--help', 'Display this help message') do
      puts parse
      exit
    end
  end.parse!
  options
end

def parse(csv, entry, redmine)
  redmine.login
  each_row(csv) do |row|
    begin
      entry.row = row
      if not entry.ignored?
        redmine.timelog entry.task, entry.date, entry.time
      end
    rescue Exception
      print "ERROR: #{row.join ','}"
      raise
    end
  end
end

def run(csv, config, options)
  parser = RowParser.new config['replace'], config['ignore']
  if options['dry-run']
    redmine = DryRedmine.new
  else
    redmine = Redmine.new config['redmine']['url'],
                          config['redmine']['username'],
                          config['redmine']['password']
  end
  parse csv, parser, redmine
end

def go
  config = open(CONFIG_FILE) { |file| YAML.load(file) }
  csv = open config['csv_file'], 'rb'
  options = parse_args
  run csv, config, options
end

if __FILE__ == $0
  go
end
